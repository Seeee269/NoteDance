#!/usr/bin/env python3
"""
CMLS Project — Sensor → OSC bridge.

Reads "x,y,z\\n" lines from the Arduino serial port (units of g),
derives tilt and shake values, and forwards them as OSC to both
SuperCollider and the JUCE plugin.

OSC addresses (matching supercollider/cmls_proj.scd):
    /sensor/accel  x y z          float, normalised to -1..1
    /sensor/tilt   roll pitch     float, radians
    /sensor/shake  magnitude      float, 0..~

Usage:
    python3 bridge.py --port /dev/tty.usbmodem1101
    python3 bridge.py --mock              # no hardware, emits a slow sine
    python3 bridge.py --port ... --debug  # print each OSC message
"""

import argparse
import math
import sys
import time

import serial
from pythonosc.udp_client import SimpleUDPClient


# -------- defaults --------
SC_HOST,   SC_PORT   = "127.0.0.1", 57120
JUCE_HOST, JUCE_PORT = "127.0.0.1", 9001
BAUD = 115200
ACCEL_RANGE_G = 1.5   # must match the Arduino's g-range (MMA7361 +-1.5g default)
SHAKE_SMOOTH  = 0.85  # IIR coefficient; higher = smoother


def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument("--port", help="serial port, e.g. /dev/tty.usbmodem1101")
    p.add_argument("--baud", type=int, default=BAUD)
    p.add_argument("--sc",   default=f"{SC_HOST}:{SC_PORT}")
    p.add_argument("--juce", default=f"{JUCE_HOST}:{JUCE_PORT}")
    p.add_argument("--mock", action="store_true",
                   help="don't open serial, generate a slow sine wave instead")
    p.add_argument("--debug", action="store_true")
    return p.parse_args()


def make_client(spec):
    host, port = spec.split(":")
    return SimpleUDPClient(host, int(port))


class Sender:
    """Fan-out sender: every message goes to both SC and JUCE."""
    def __init__(self, sc, juce, debug=False):
        self.sc = sc
        self.juce = juce
        self.debug = debug

    def send(self, addr, args):
        self.sc.send_message(addr, args)
        self.juce.send_message(addr, args)
        if self.debug:
            print(f"{addr} {args}")


def normalize_axis(g_value, full_scale):
    """Map a g-value into -1..1, clipped to range."""
    v = g_value / full_scale
    return max(-1.0, min(1.0, v))


def tilt_from_accel(x, y, z):
    """Roll / pitch in radians, assuming gravity dominates the signal."""
    roll  = math.atan2(y, z)
    pitch = math.atan2(-x, math.sqrt(y * y + z * z) + 1e-9)
    return roll, pitch


def process_and_send(sender, x_g, y_g, z_g, state):
    x = normalize_axis(x_g, ACCEL_RANGE_G)
    y = normalize_axis(y_g, ACCEL_RANGE_G)
    z = normalize_axis(z_g, ACCEL_RANGE_G)

    roll, pitch = tilt_from_accel(x, y, z)

    px, py, pz = state["prev"]
    dx, dy, dz = x - px, y - py, z - pz
    inst = math.sqrt(dx * dx + dy * dy + dz * dz)
    state["shake"] = SHAKE_SMOOTH * state["shake"] + (1 - SHAKE_SMOOTH) * inst
    state["prev"] = (x, y, z)

    sender.send("/sensor/accel", [x, y, z])
    sender.send("/sensor/tilt",  [roll, pitch])
    sender.send("/sensor/shake", [state["shake"]])


def run_serial(args, sender):
    print(f"opening {args.port} @ {args.baud}", file=sys.stderr)
    ser = serial.Serial(args.port, args.baud, timeout=1)
    time.sleep(2)  # wait out the Arduino auto-reset
    ser.reset_input_buffer()

    state = {"prev": (0.0, 0.0, 0.0), "shake": 0.0}
    while True:
        raw = ser.readline().decode("utf-8", errors="ignore").strip()
        if not raw or raw.startswith("ERR"):
            if raw:
                print(raw, file=sys.stderr)
            continue
        try:
            x_g, y_g, z_g = (float(v) for v in raw.split(","))
        except ValueError:
            continue
        process_and_send(sender, x_g, y_g, z_g, state)


def run_mock(sender):
    """No-hardware mode: drive the axes with slow sines for SC/JUCE testing."""
    print("mock mode -- Ctrl+C to stop", file=sys.stderr)
    state = {"prev": (0.0, 0.0, 0.0), "shake": 0.0}
    t0 = time.time()
    while True:
        t = time.time() - t0
        x_g = 1.5 * math.sin(2 * math.pi * 0.20 * t)
        y_g = 1.5 * math.sin(2 * math.pi * 0.13 * t + 1.0)
        z_g = 1.0 + 0.3 * math.sin(2 * math.pi * 0.30 * t)
        process_and_send(sender, x_g, y_g, z_g, state)
        time.sleep(0.02)  # 50 Hz


def main():
    args = parse_args()
    sender = Sender(make_client(args.sc), make_client(args.juce), args.debug)

    if args.mock:
        run_mock(sender)
    else:
        if not args.port:
            sys.exit("error: --port required (or use --mock)")
        run_serial(args, sender)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass
