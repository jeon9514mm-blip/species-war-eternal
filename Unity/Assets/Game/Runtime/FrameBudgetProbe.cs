using System;
using System.Diagnostics;
using Newtonsoft.Json.Linq;

namespace Eternal.UnityMigration
{
    // Rolling source-code timings, not a GPU/standalone frame-rate claim.
    public sealed class FrameBudgetProbe
    {
        const int Capacity=1024;
        readonly double[] milliseconds=new double[Capacity],allocatedBytes=new double[Capacity];
        int cursor,count;
        long start,allocatedStart;
        readonly bool verifiedManagedCounter;
        public FrameBudgetProbe()
        {long before=GC.GetAllocatedBytesForCurrentThread();var allocation=new byte[4096];long after=GC.GetAllocatedBytesForCurrentThread();GC.KeepAlive(allocation);verifiedManagedCounter=after-before>=4096;}
        public void Begin(){start=Stopwatch.GetTimestamp();allocatedStart=GC.GetAllocatedBytesForCurrentThread();}
        public void End()
        {
            int i=cursor++%Capacity;milliseconds[i]=(Stopwatch.GetTimestamp()-start)*1000d/Stopwatch.Frequency;
            allocatedBytes[i]=Math.Max(0,GC.GetAllocatedBytesForCurrentThread()-allocatedStart);count=Math.Min(Capacity,count+1);
        }
        public JObject Snapshot()
        {
            var times=new double[count];var bytes=new double[count];Array.Copy(milliseconds,times,count);Array.Copy(allocatedBytes,bytes,count);Array.Sort(times);Array.Sort(bytes);
            double Percentile(double[] samples,double fraction)=>samples.Length==0?0:samples[Math.Clamp((int)Math.Ceiling(samples.Length*fraction)-1,0,samples.Length-1)];
            return new JObject{{"samples",count},{"source_cpu_ms_median",Percentile(times,.5)},{"source_cpu_ms_p95",Percentile(times,.95)},{"source_cpu_ms_max",Percentile(times,1)},{"managed_byte_counter_verified",verifiedManagedCounter},{"source_allocated_bytes_median",verifiedManagedCounter?Percentile(bytes,.5):JValue.CreateNull()},{"source_allocated_bytes_p95",verifiedManagedCounter?Percentile(bytes,.95):JValue.CreateNull()},{"source_allocated_bytes_max",verifiedManagedCounter?Percentile(bytes,1):JValue.CreateNull()},{"note","Measures this component's synchronous code only; excludes GPU, Editor overhead and other components. A managed-byte counter that fails a known allocation probe reports null, not zero. Diagnostic snapshot allocation is outside sampled code."}};
        }
    }
}
