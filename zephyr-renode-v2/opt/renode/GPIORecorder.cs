// GPIORecorder: writes every level change on chosen GPIO lines to a file, stamped with simulated
// time. Lines are caught inside Renode (GPIO state-change hooks), so the stamps are virtual time and
// repeat run to run, like CANRecorder.cs.
//
// Monitor usage:
//   include @/opt/zephyr-v2/renode/GPIORecorder.cs
//   emulation CreateGPIORecorder "gpioRec" @/out/pins.txt
//   gpioRec WatchPin "led" sysbus.gpioPortB 0          # the level of pin 0 of a GPIO port
//   gpioRec WatchGPIO "btn" sysbus.gpioPortC.UserButton1 "IRQ"   # any GPIO property of a peripheral
//   gpioRec Mark "probe"                                # a line "<ns> # probe" (to line up a script)
//
// WatchPin takes any peripheral with numbered GPIO outputs (INumberedGPIOOutput: STM32 GPIO ports,
// nRF GPIO, SiFive GPIO, ...) and hooks Connections[pin]. On an STM32 port that line carries the
// pin's level whichever way it is driven: by the firmware (ODR or BSRR writes, the pin as an output)
// or from outside (OnGPIO on the port, a Button; it is what the port passes on to EXTI). So it is
// what a logic analyser on the pin would show. Call WatchPin before the emulation starts.
//
// Line format, one per change (no line when a write leaves the level as it was):
//   <virtual ns> <name> <0|1>
// The first line for each name is its level when the watch started (normally ns 0).
// A hook runs in the thread that changed the line: the CPU's thread for a firmware write (the stamp
// is that CPU's virtual time, instruction-accurate), the Monitor's thread for a change made from the
// script while the emulation is paused (the stamp is the paused time).
using System;
using System.Collections.Generic;
using System.IO;
using System.Reflection;

using Antmicro.Renode.Core;
using Antmicro.Renode.Exceptions;
using Antmicro.Renode.Peripherals;
using Antmicro.Renode.Time;

namespace Antmicro.Renode.Testing
{
    public static class GPIORecorderExtensions
    {
        public static void CreateGPIORecorder(this Emulation emulation, string name, string path)
        {
            emulation.ExternalsManager.AddExternal(new GPIORecorder(path), name);
        }
    }

    public sealed class GPIORecorder : IExternal
    {
        public GPIORecorder(string path)
        {
            writer = new StreamWriter(path, false) { AutoFlush = true };
        }

        public void WatchPin(string name, IPeripheral port, int pin)
        {
            if(!(port is INumberedGPIOOutput outputs))
            {
                throw new RecoverableException($"{port.GetType().Name} has no numbered GPIO outputs");
            }
            if(!outputs.Connections.TryGetValue(pin, out var line))
            {
                throw new RecoverableException($"{port.GetType().Name} has no pin {pin}");
            }
            Watch(name, line);
        }

        public void WatchGPIO(string name, IPeripheral peripheral, string property)
        {
            var p = peripheral.GetType().GetProperty(property, BindingFlags.Public | BindingFlags.Instance);
            if(p == null || !(p.GetValue(peripheral) is IGPIO line))
            {
                throw new RecoverableException($"{peripheral.GetType().Name} has no GPIO property '{property}'");
            }
            Watch(name, line);
        }

        public void Mark(string label)
        {
            lock(writer)
            {
                writer.WriteLine($"{Now().TotalNanoseconds} # {label}");
            }
        }

        private void Watch(string name, IGPIO line)
        {
            if(name.Contains(" ") || name.Length == 0)
            {
                throw new RecoverableException($"GPIO watch name '{name}' must be one word");
            }
            if(!(line is IGPIOWithHooks hooked))
            {
                throw new RecoverableException($"the line for '{name}' does not take hooks");
            }
            lock(writer)
            {
                if(last.ContainsKey(name))
                {
                    throw new RecoverableException($"'{name}' is already watched");
                }
                last[name] = line.IsSet;
                writer.WriteLine($"{Now().TotalNanoseconds} {name} {(line.IsSet ? 1 : 0)}");
            }
            hooked.AddStateChangedHook(level => Record(name, level));
        }

        private void Record(string name, bool level)
        {
            var t = Now();
            lock(writer)
            {
                if(last[name] == level)
                {
                    return;
                }
                last[name] = level;
                writer.WriteLine($"{t.TotalNanoseconds} {name} {(level ? 1 : 0)}");
            }
        }

        private static TimeInterval Now()
        {
            // In a CPU thread this is that CPU's own virtual time; elsewhere (the Monitor, with the
            // emulation paused) the master time source's.
            return TimeDomainsManager.Instance.TryGetVirtualTimeStamp(out var ts)
                ? ts.TimeElapsed
                : EmulationManager.Instance.CurrentEmulation.MasterTimeSource.ElapsedVirtualTime;
        }

        private readonly StreamWriter writer;
        private readonly Dictionary<string, bool> last = new Dictionary<string, bool>();
    }
}
