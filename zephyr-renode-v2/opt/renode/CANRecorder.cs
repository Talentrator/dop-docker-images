// CANRecorder: writes every frame that reaches a Renode CAN hub to a file, stamped with the
// sender's simulated time. Frames are caught inside Renode, never through a host CAN
// interface, so the stamps are virtual time and repeat run to run.
//   include @CANRecorder.cs
//   emulation CreateCANHub "canHub"
//   connector Connect sysbus.can1 canHub
//   emulation CreateCANRecorder "canRec" "canHub" @/out/frames.txt
// Line format: <virtual ns> <sender> <id hex> <ext 0|1> <rtr 0|1> <dlc> <data hex>
using System;
using System.IO;
using System.Linq;

using Antmicro.Renode.Core;
using Antmicro.Renode.Core.CAN;
using Antmicro.Renode.Exceptions;
using Antmicro.Renode.Peripherals;
using Antmicro.Renode.Peripherals.CAN;
using Antmicro.Renode.Time;
using Antmicro.Renode.Tools.Network;

namespace Antmicro.Renode.Testing
{
    public static class CANRecorderExtensions
    {
        public static void CreateCANRecorder(this Emulation emulation, string name, string hubName, string path)
        {
            if(!emulation.ExternalsManager.TryGetByName<CANHub>(hubName, out var hub))
            {
                throw new RecoverableException($"No CAN hub named '{hubName}'");
            }
            emulation.ExternalsManager.AddExternal(new CANRecorder(hub, path), name);
        }
    }

    public sealed class CANRecorder : IExternal
    {
        public CANRecorder(CANHub hub, string path)
        {
            writer = new StreamWriter(path, false) { AutoFlush = true };
            hub.FrameReceived += (_, sender, frame) => Record(sender, frame);
        }

        private void Record(ICAN sender, CANMessageFrame frame)
        {
            // FrameReceived runs in the sending CPU's thread, so this is the sender's local
            // virtual time at the moment its controller put the frame on the hub.
            var t = TimeDomainsManager.Instance.TryGetVirtualTimeStamp(out var ts)
                ? ts.TimeElapsed
                : EmulationManager.Instance.CurrentEmulation.MasterTimeSource.ElapsedVirtualTime;
            var name = sender is IPeripheral p ? (p.TryGetMachine(out var m) && m.TryGetAnyName(p, out var n) ? n : sender.GetType().Name) : "external";
            var data = string.Concat(frame.Data.Select(b => b.ToString("x2")));
            lock(writer)
            {
                writer.WriteLine($"{t.TotalNanoseconds} {name} {frame.Id:x} {(frame.ExtendedFormat ? 1 : 0)} {(frame.RemoteFrame ? 1 : 0)} {frame.Data.Length} {(data.Length > 0 ? data : "-")}");
            }
        }

        private readonly StreamWriter writer;
    }
}
