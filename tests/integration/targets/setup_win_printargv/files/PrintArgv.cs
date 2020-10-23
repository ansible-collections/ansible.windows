using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Web.Script.Serialization;

namespace PrintArgv
{
    class Program
    {
        [DllImport("Kernel32.dll")]
        public static extern IntPtr GetCommandLineW();

        static void Main(string[] args)
        {
            IntPtr cmdLinePtr = GetCommandLineW();
            string cmdLine = Marshal.PtrToStringUni(cmdLinePtr);

            Dictionary<string, object> cmdInfo = new Dictionary<string, object>()
            {
                {"command_line", cmdLine },
                {"args", args},
            };

            JavaScriptSerializer jss = new JavaScriptSerializer();
            jss.MaxJsonLength = int.MaxValue;
            jss.RecursionLimit = int.MaxValue;
            Console.WriteLine(jss.Serialize(cmdInfo));
        }
    }
}
