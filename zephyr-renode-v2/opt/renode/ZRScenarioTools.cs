// ZRScenarioTools: recorders and an injector for zr-scenario, stamped with simulated time.
//
// Monitor usage:
//   include @/opt/zephyr-v2/renode/ZRScenarioTools.cs
//   emulation CreateResetRecorder "resetRec" "board" @/out/resets.txt
//       one line "<virtual ns> reset" per machine reset (a watchdog, SYSRESETREQ, sys_reboot)
//   emulation CreateUARTRecorder "uartRec" sysbus.usart3 @/out/uart-timed.txt
//       one line "<virtual ns> <byte hex>" per character the firmware sends on that UART
//   sysbus.can1 InjectFrame 0x123 "0102030405060708" false
//       hands a frame to that CAN controller as if an external node had sent it (id, data in hex,
//       extended id). It goes to the controller directly, not through a hub: CANHub names every
//       sender through the machine it belongs to, so a node outside the machine cannot send on
//       one. The frame is therefore not in CANRecorder's file; zr-scenario adds it to the frame
//       list itself, as sent by "external".
//
// A recorder hook runs in the thread that caused the event: the CPU's thread for a firmware write
// (that CPU's virtual time), the Monitor's thread while the emulation is paused (the paused time).
using System;
using System.IO;
using System.Linq;

using Antmicro.Renode.Core;
using Antmicro.Renode.Core.CAN;
using Antmicro.Renode.Exceptions;
using Antmicro.Renode.Peripherals.CAN;
using Antmicro.Renode.Peripherals.UART;
using Antmicro.Renode.Time;

namespace Antmicro.Renode.Testing
{
    public static class ZRScenarioToolsExtensions
    {
        public static void CreateResetRecorder(this Emulation emulation, string name, string machineName, string path)
        {
            if(!emulation.TryGetMachineByName(machineName, out var machine))
            {
                throw new RecoverableException($"No machine named '{machineName}'");
            }
            emulation.ExternalsManager.AddExternal(new ResetRecorder(machine, path), name);
        }

        public static void CreateUARTRecorder(this Emulation emulation, string name, IUART uart, string path)
        {
            emulation.ExternalsManager.AddExternal(new UARTRecorder(uart, path), name);
        }

        public static void InjectFrame(this ICAN can, uint id, string dataHex, bool extended = false, bool remote = false)
        {
            dataHex = dataHex ?? "";
            if(dataHex.Length % 2 != 0 || dataHex.Length > 16)
            {
                throw new RecoverableException($"CAN data '{dataHex}' must be 0 to 8 bytes in hex");
            }
            var data = Enumerable.Range(0, dataHex.Length / 2)
                .Select(i => Convert.ToByte(dataHex.Substring(2 * i, 2), 16)).ToArray();
            can.OnFrameReceived(new CANMessageFrame(id, data, extended, remote, false, false));
        }

        internal static TimeInterval Now()
        {
            return TimeDomainsManager.Instance.TryGetVirtualTimeStamp(out var ts)
                ? ts.TimeElapsed
                : EmulationManager.Instance.CurrentEmulation.MasterTimeSource.ElapsedVirtualTime;
        }
    }

    public sealed class ResetRecorder : IExternal
    {
        public ResetRecorder(IMachine machine, string path)
        {
            writer = new StreamWriter(path, false) { AutoFlush = true };
            machine.MachineReset += m =>
            {
                // A reset is carried out with the machine paused at a synced point: its own clock
                // is the time the reset took effect.
                var t = m.ElapsedVirtualTime.TimeElapsed;
                lock(writer)
                {
                    writer.WriteLine($"{t.TotalNanoseconds} reset");
                }
            };
        }

        private readonly StreamWriter writer;
    }

    public sealed class UARTRecorder : IExternal
    {
        public UARTRecorder(IUART uart, string path)
        {
            writer = new StreamWriter(path, false) { AutoFlush = true };
            uart.CharReceived += b =>
            {
                var t = ZRScenarioToolsExtensions.Now();
                lock(writer)
                {
                    writer.WriteLine($"{t.TotalNanoseconds} {b:x2}");
                }
            };
        }

        private readonly StreamWriter writer;
    }
}
