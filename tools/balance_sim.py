#!/usr/bin/env python3
"""Denge simulasyonu (A7). data/orbiters ve data/upgrades altindaki .tres dosyalarini okur,
her seferinde en iyi geri-donus suresine sahip seyi alan bir oyuncuyu simule eder ve
kilometre taslarinin zamanlarini yazdirir.

Kullanim:  python3 tools/balance_sim.py [--cps 3 0.5] [--hours 48]

Varsayimlar: oyuncu hep en kisa geri-donuslu seyi (maliyet / gelir artisi) alir (gercek
oyuncudan verimli, yani gercek sureler daha uzun olur); tik hizi sabit; Economy ile ayni
formuller (tik = 1 x tik carpani x genel carpan; orbiter geliri = taban x adet x orbiter
carpani x tum orbiter carpani x genel carpan; auto_click tik/sn eklenir).
"""
import argparse
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PROP = re.compile(r'^(\w+) = (.+)$', re.M)


def read_tres(path):
    props = {}
    for key, raw in PROP.findall(path.read_text(encoding="utf-8")):
        raw = raw.strip()
        if raw.startswith('&"') or raw.startswith('"'):
            props[key] = raw.lstrip('&').strip('"')
        else:
            try:
                props[key] = float(raw)
            except ValueError:
                pass
    return props


def load():
    orbiters = [read_tres(p) for p in sorted((ROOT / "data/orbiters").glob("*.tres"))]
    upgrades = [read_tres(p) for p in sorted((ROOT / "data/upgrades").glob("*.tres"))]
    orbiters = [o for o in orbiters if "base_cost" in o]
    upgrades = [u for u in upgrades if "cost" in u]
    orbiters.sort(key=lambda o: o["base_cost"])
    return orbiters, upgrades


def income(orbiters, upgrades, counts, bought, clicks_per_sec):
    click_mult = global_mult = orbiters_mult = 1.0
    auto = 0.0
    per_orbiter = {}
    for u in upgrades:
        if u["id"] not in bought:
            continue
        t, v = u["type"], u["value"]
        if t == "per_click":
            click_mult *= v
        elif t == "all_income":
            global_mult *= v
        elif t == "all_orbiters":
            orbiters_mult *= v
        elif t == "auto_click":
            auto += v
        elif t == "orbiter":
            per_orbiter[u["target_orbiter_id"]] = per_orbiter.get(u["target_orbiter_id"], 1.0) * v
    click_value = click_mult * global_mult
    orbiter_income = sum(
        o["base_income"] * counts[o["id"]] * per_orbiter.get(o["id"], 1.0) for o in orbiters
    ) * orbiters_mult * global_mult
    return orbiter_income + click_value * (clicks_per_sec + auto)


def simulate(orbiters, upgrades, clicks_per_sec, horizon):
    counts = {o["id"]: 0 for o in orbiters}
    bought = set()
    milestones = {}
    t = money = 0.0
    while t < horizon:
        current = income(orbiters, upgrades, counts, bought, clicks_per_sec)
        options = []
        for o in orbiters:
            cost = o["base_cost"] * o["cost_growth"] ** counts[o["id"]]
            counts[o["id"]] += 1
            gain = income(orbiters, upgrades, counts, bought, clicks_per_sec) - current
            counts[o["id"]] -= 1
            options.append((cost / gain if gain > 0 else 1e30, cost, ("orbiter", o["id"])))
        for u in upgrades:
            if u["id"] in bought:
                continue
            bought.add(u["id"])
            gain = income(orbiters, upgrades, counts, bought, clicks_per_sec) - current
            bought.discard(u["id"])
            options.append((u["cost"] / gain if gain > 0 else 1e30, u["cost"], ("upgrade", u["id"])))
        options.sort()
        _, cost, (kind, ident) = options[0]
        wait = max(0.0, (cost - money) / current) if current > 0 else 1e30
        if t + wait > horizon:
            break
        t += wait
        money += current * wait - cost
        if kind == "orbiter":
            counts[ident] += 1
            if counts[ident] in (1, 10, 25):
                milestones[f"{ident} #{counts[ident]}"] = t
        else:
            bought.add(ident)
            milestones[ident] = t
    return milestones, counts, income(orbiters, upgrades, counts, bought, clicks_per_sec), bought


def fmt(seconds):
    h, rem = divmod(int(seconds), 3600)
    m, s = divmod(rem, 60)
    return f"{h}sa {m:02d}dk" if h else f"{m}dk {s:02d}sn"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--cps", type=float, nargs="+", default=[3.0, 0.5], help="saniyedeki tik sayisi profilleri")
    parser.add_argument("--hours", type=float, default=48.0)
    args = parser.parse_args()
    orbiters, upgrades = load()
    print(f"{len(orbiters)} orbiter, {len(upgrades)} upgrade okundu.")
    for cps in args.cps:
        milestones, counts, final_income, bought = simulate(orbiters, upgrades, cps, args.hours * 3600)
        print(f"\n== {cps} tik/sn")
        for key, seconds in sorted(milestones.items(), key=lambda kv: kv[1]):
            print(f"  {key:22s} {fmt(seconds)}")
        remaining = [u["id"] for u in upgrades if u["id"] not in bought]
        if remaining:
            print(f"  ({args.hours:g} saatte alinamayan upgrade'ler: {', '.join(remaining)})")
        print(f"  {args.hours:g}. saat: gelir {final_income:.3g}/sn, adetler {list(counts.values())}")


if __name__ == "__main__":
    main()
