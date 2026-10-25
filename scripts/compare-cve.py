#!/usr/bin/env python3
"""Resume dos capturas comparables sin atribuir una CVE automáticamente."""

import argparse
import json
import re
from pathlib import Path


def read(path):
    return path.read_text(encoding="utf-8", errors="replace") if path.exists() else ""


def fields(path):
    return dict(line.split("=", 1) for line in read(path).splitlines() if "=" in line)


def inspect_state(path):
    try:
        container = json.loads(read(path))[0]
        return container.get("State", {}), container.get("RestartCount", 0)
    except (ValueError, IndexError, KeyError, TypeError, AttributeError):
        return {}, None


def apache_pids(path):
    pids = set()
    for line in read(path).splitlines():
        parts = line.split()
        if len(parts) >= 6 and parts[0].isdigit() and re.search(r"(?:apache2|httpd)$", parts[-1]):
            pids.add(parts[0])
    return pids


def observations(path):
    rows, errors = [], []
    for line in read(path).splitlines():
        if not line or line.startswith("#") or line.startswith("timestamp_utc"):
            continue
        parts = line.split("\t")
        if len(parts) != 4 or not re.fullmatch(r"[0-9]{3}", parts[3]):
            errors.append(f"fila HTTP inválida: {line[:120]}")
            continue
        rows.append(parts)
    return rows, errors


def process_changes(folder):
    paths = ([folder / "processes-before.txt"]
             + sorted(folder.glob("processes-during-*.txt"))
             + [folder / "processes-after.txt"])
    sets = [apache_pids(path) for path in paths]
    observed = [pids for pids in sets if pids]
    removed = set()
    added = set()
    for before, after in zip(observed, observed[1:]):
        removed.update(before - after)
        added.update(after - before)
    return sorted(removed, key=int), sorted(added, key=int), len(observed)


def mebibytes(value):
    match = re.match(r"\s*([0-9.]+)\s*([KMG]i?B|B)", value)
    if not match:
        return None
    amount, unit = float(match[1]), match[2]
    factor = {"B": 1 / 1048576, "KB": 1 / 1024, "KiB": 1 / 1024,
              "MB": 1, "MiB": 1, "GB": 1024, "GiB": 1024}[unit]
    return amount * factor


def resource_peaks(folder):
    cpu, memory = [], []
    for path in folder.glob("resources-*.txt"):
        for line in read(path).splitlines():
            try:
                sample = json.loads(line)
                cpu.append(float(sample["CPUPerc"].rstrip("%")))
                used = mebibytes(sample["MemUsage"].split("/")[0])
                if used is not None:
                    memory.append(used)
            except (ValueError, KeyError, TypeError, AttributeError):
                continue
    return f"{max(cpu):.2f}%" if cpu else "—", f"{max(memory):.2f} MiB" if memory else "—"


def summarize(folder):
    meta = fields(folder / "experiment.txt")
    missing = [name for name in ("experiment.txt", "container-inspect-before.json",
             "container-inspect-after.json", "processes-before.txt", "processes-after.txt",
             "docker-events.jsonl", "php-apache-logs.txt", "health-after.txt",
             "compose-effective.yaml") if not (folder / name).is_file()]
    if not list(folder.glob("resources-*.txt")):
        missing.append("resources-*.txt")
    if "ended_at_utc" not in meta:
        missing.append("ended_at_utc (captura incompleta)")
    before, restart_before = inspect_state(folder / "container-inspect-before.json")
    after, restart_after = inspect_state(folder / "container-inspect-after.json")
    events = []
    for line in read(folder / "docker-events.jsonl").splitlines():
        try:
            event = json.loads(line)
            if isinstance(event, dict):
                events.append(event.get("Action", ""))
        except (ValueError, TypeError):
            pass
    logs = read(folder / "php-apache-logs.txt")
    removed, added, valid_process_samples = process_changes(folder)
    http, http_errors = observations(folder / "http-observations.tsv")
    health_code = fields(folder / "health-after.txt").get("http_code", "")

    signals = []
    if health_code.isdigit() and 200 <= int(health_code) < 400:
        signals.append("respuesta HTTP normal de control")
    if any(200 <= int(row[3]) < 400 for row in http):
        signals.append("respuesta HTTP normal (solicitud registrada)")
    if any(int(row[3]) >= 400 for row in http):
        signals.append("respuesta HTTP de error; origen por confirmar")
    if any(re.search(r"PHP (?:Fatal error|Warning|Parse error|Uncaught)", line, re.I)
           and "Allowed memory size" not in line for line in logs.splitlines()):
        signals.append("error de aplicación/PHP registrado")
    if re.search(r"Allowed memory size of .* exhausted", logs, re.I):
        signals.append("agotamiento de memoria de PHP registrado")
    if before.get("OOMKilled") or after.get("OOMKilled") or "oom" in events:
        signals.append("OOM del contenedor registrado")
    if removed or re.search(r"child pid \d+ exit signal", logs, re.I):
        signals.append("terminación o reemplazo de procesos Apache observado")
    if (meta.get("container_id_after") and meta.get("container_id_after") != meta.get("container_id") or
            (restart_before is not None and restart_after is not None and restart_after > restart_before) or
            "restart" in events):
        signals.append("reinicio o recreación del contenedor observado")

    instrument = folder / "instrumentation.json"
    try:
        claim = json.loads(read(instrument)) if instrument.exists() else {}
    except ValueError:
        claim = {}
    if not isinstance(claim, dict):
        claim = {}
    trace_name = claim.get("trace_file", "")
    trace = folder / trace_name if isinstance(trace_name, str) else folder
    if (claim.get("reviewed") is True and claim.get("finding") == "memory_corruption"
            and isinstance(claim.get("tool"), str) and claim["tool"]
            and isinstance(trace_name, str) and trace_name
            and trace.resolve().is_relative_to(folder.resolve())
            and trace.is_file() and trace.stat().st_size > 0):
        signals.append("corrupción de memoria confirmada por traza instrumentada y revisión declarada")
    if not http or missing or http_errors:
        signals.append("evidencia insuficiente")

    cpu_peak, memory_peak = resource_peaks(folder)

    return {
        "meta": meta,
        "signals": signals,
        "missing": missing,
        "http_errors": http_errors,
        "removed": removed,
        "added": added,
        "process_samples": valid_process_samples,
        "restart_before": restart_before,
        "restart_after": restart_after,
        "events": sorted({event.split(":", 1)[0] for event in events if isinstance(event, str) and event}),
        "health_code": health_code or "—",
        "samples": len(list(folder.glob("resources-during-*.txt"))),
        "cpu_peak": cpu_peak,
        "memory_peak": memory_peak,
        "http_count": len(http),
        "worker_pids": sorted({row[2] for row in http if row[2]}, key=str),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("vulnerable", type=Path)
    parser.add_argument("patched", type=Path)
    args = parser.parse_args()
    left, right = summarize(args.vulnerable), summarize(args.patched)
    print("# Comparación diagnóstica\n")
    print("| Evidencia | PHP 8.4.26 | PHP 8.4.27 |")
    print("|---|---|---|")
    for label, key in [("Servicio", "service"), ("Versión registrada", "php_version"),
                       ("Etiqueta", "label"),
                       ("Inicio UTC", "started_at_utc"), ("Fin UTC", "ended_at_utc"),
                       ("Contenedor inicial", "container_id")]:
        print(f"| {label} | {left['meta'].get(key, '—')} | {right['meta'].get(key, '—')} |")
    for label, key in [("Muestras de recursos", "samples"),
                       ("Muestras válidas de procesos", "process_samples"),
                       ("CPU máxima observada", "cpu_peak"),
                       ("Memoria máxima observada", "memory_peak"),
                       ("HTTP de salud posterior", "health_code"),
                       ("Solicitudes HTTP documentadas", "http_count"),
                       ("PID de solicitudes documentadas", "worker_pids"),
                       ("Eventos Docker", "events"),
                       ("PID Apache ausentes al final", "removed"), ("PID Apache nuevos", "added"),
                       ("Reinicios antes/después", "restart")]:
        def value(run):
            if key == "restart":
                before = run["restart_before"]
                after = run["restart_after"]
                return f"{before}/{after}" if before is not None and after is not None else "—"
            item = run[key]
            return ", ".join(item) if isinstance(item, list) else item
        a, b = value(left), value(right)
        print(f"| {label} | {a if a != '' else '—'} | {b if b != '' else '—'} |")
    print("\n## Clasificación de señales\n")
    for name, run in [("PHP 8.4.26", left), ("PHP 8.4.27", right)]:
        print(f"**{name}:** {', '.join(run['signals'])}.")
    print("\n## Integridad de la evidencia\n")
    for name, expected, run in [("PHP 8.4.26", "vulnerable", left),
                                ("PHP 8.4.27", "patched", right)]:
        issues = [f"falta {item}" for item in run["missing"]] + run["http_errors"]
        if run["meta"].get("service") != expected:
            issues.append(f"servicio registrado distinto de {expected}")
        if run["meta"].get("php_version") != name.removeprefix("PHP "):
            issues.append("versión ausente o inesperada")
        if not (run["meta"].get("container_id") and run["meta"].get("container_id_after")):
            issues.append("identidad del contenedor incompleta")
        print(f"- {name}: {'; '.join(issues) if issues else 'archivos esenciales presentes'}.")
    if left["meta"].get("label") != right["meta"].get("label"):
        print("- Las etiquetas experimentales difieren; comprobar comparabilidad manualmente.")
    print("\nLas categorías son señales independientes. Un código HTTP, un PID ausente o una caída "
          "no atribuyen ninguna CVE. Un PID ausente puede deberse al reciclaje normal de Apache. "
          "Para CVE-2026-109619, los PID de solicitudes productor y consumidor deben coincidir; "
          "esta tabla no demuestra que se haya producido o consumido estado obsoleto.")


if __name__ == "__main__":
    main()
