using Microsoft.Win32.SafeHandles;
using System;
using System.Collections;
using System.IO;
using System.Linq;
using System.Runtime.ConstrainedExecution;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

//TypeAccelerator -Name Ansible.Windows.Process.ProcessUtil -TypeName ProcessUtil
//TypeAccelerator -Name Ansible.Windows.Process.Result -TypeName Result

namespace ansible_collections.ansible.windows.plugins.module_utils.Process
{
    internal class NativeHelpers
    {
        [StructLayout(LayoutKind.Sequential)]
        public struct JOBOBJECT_ASSOCIATE_COMPLETION_PORT
        {
            public IntPtr CompletionKey;
            public IntPtr CompletionPort;
        }

        [StructLayout(LayoutKind.Sequential)]
        public class SECURITY_ATTRIBUTES
        {
            public UInt32 nLength;
            public IntPtr lpSecurityDescriptor;
            public bool bInheritHandle = false;
            public SECURITY_ATTRIBUTES()
            {
                nLength = (UInt32)Marshal.SizeOf(this);
            }
        }

        [StructLayout(LayoutKind.Sequential)]
        public class STARTUPINFO
        {
            public UInt32 cb;
            public IntPtr lpReserved;
            [MarshalAs(UnmanagedType.LPWStr)] public string lpDesktop;
            [MarshalAs(UnmanagedType.LPWStr)] public string lpTitle;
            public UInt32 dwX;
            public UInt32 dwY;
            public UInt32 dwXSize;
            public UInt32 dwYSize;
            public UInt32 dwXCountChars;
            public UInt32 dwYCountChars;
            public UInt32 dwFillAttribute;
            public StartupInfoFlags dwFlags;
            public UInt16 wShowWindow;
            public UInt16 cbReserved2;
            public IntPtr lpReserved2;
            public SafeFileHandle hStdInput;
            public SafeFileHandle hStdOutput;
            public SafeFileHandle hStdError;
            public STARTUPINFO()
            {
                cb = (UInt32)Marshal.SizeOf(this);
            }
        }

        [StructLayout(LayoutKind.Sequential)]
        public class STARTUPINFOEX
        {
            public STARTUPINFO startupInfo;
            public IntPtr lpAttributeList;
            public STARTUPINFOEX()
            {
                startupInfo = new STARTUPINFO();
                startupInfo.cb = (UInt32)Marshal.SizeOf(this);
            }
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct PROCESS_INFORMATION
        {
            public IntPtr hProcess;
            public IntPtr hThread;
            public int dwProcessId;
            public int dwThreadId;
        }

        public enum JobObjectInformationClass : uint
        {
            JobObjectAssociateCompletionPortInformation = 7,
        }

        [Flags]
        public enum ProcessCreationFlags : uint
        {
            CREATE_SUSPENDED = 0x00000004,
            CREATE_NEW_CONSOLE = 0x00000010,
            CREATE_UNICODE_ENVIRONMENT = 0x00000400,
            EXTENDED_STARTUPINFO_PRESENT = 0x00080000
        }

        [Flags]
        public enum StartupInfoFlags : uint
        {
            USESTDHANDLES = 0x00000100
        }

        [Flags]
        public enum HandleFlags : uint
        {
            None = 0,
            INHERIT = 1
        }
    }

    internal class NativeMethods
    {
        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool AllocConsole();

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool AssignProcessToJobObject(
            SafeHandle hJob,
            IntPtr hProcess);

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool CloseHandle(
            IntPtr hObject);

        [DllImport("shell32.dll", SetLastError = true)]
        public static extern SafeMemoryBuffer CommandLineToArgvW(
            [MarshalAs(UnmanagedType.LPWStr)] string lpCmdLine,
            out int pNumArgs);

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern SafeNativeHandle CreateIoCompletionPort(
            IntPtr FileHandle,
            IntPtr ExistingCompletionPort,
            UIntPtr CompletionKey,
            UInt32 NumberOfConcurrentThreads);

        [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        public static extern SafeNativeHandle CreateJobObjectW(
            IntPtr lpJobAttributes,
            string lpName);

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool CreatePipe(
            out SafeFileHandle hReadPipe,
            out SafeFileHandle hWritePipe,
            NativeHelpers.SECURITY_ATTRIBUTES lpPipeAttributes,
            UInt32 nSize);

        [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        public static extern bool CreateProcessW(
            [MarshalAs(UnmanagedType.LPWStr)] string lpApplicationName,
            StringBuilder lpCommandLine,
            IntPtr lpProcessAttributes,
            IntPtr lpThreadAttributes,
            bool bInheritHandles,
            NativeHelpers.ProcessCreationFlags dwCreationFlags,
            SafeMemoryBuffer lpEnvironment,
            [MarshalAs(UnmanagedType.LPWStr)] string lpCurrentDirectory,
            NativeHelpers.STARTUPINFOEX lpStartupInfo,
            out NativeHelpers.PROCESS_INFORMATION lpProcessInformation);

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool FreeConsole();

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern IntPtr GetConsoleWindow();

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool GetExitCodeProcess(
            SafeWaitHandle hProcess,
            out UInt32 lpExitCode);

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool GetQueuedCompletionStatus(
            IntPtr CompletionPort,
            out UInt32 lpNumberOfBytesTransferred,
            out UIntPtr lpCompletionKey,
            out IntPtr lpOverlapped,
            UInt32 dwMilliseconds);

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern UInt32 ResumeThread(
            IntPtr hThread);

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool SetConsoleCP(
            UInt32 wCodePageID);

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool SetConsoleOutputCP(
            UInt32 wCodePageID);

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool SetHandleInformation(
            SafeFileHandle hObject,
            NativeHelpers.HandleFlags dwMask,
            NativeHelpers.HandleFlags dwFlags);

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool SetInformationJobObject(
            SafeHandle hJob,
            NativeHelpers.JobObjectInformationClass JobObjectInformationClass,
            IntPtr lpJobObjectInformation,
            Int32 cbJobObjectInformationLength);

        [DllImport("kernel32.dll")]
        public static extern UInt32 WaitForSingleObject(
            SafeWaitHandle hHandle,
            UInt32 dwMilliseconds);
    }

    internal class SafeMemoryBuffer : SafeHandleZeroOrMinusOneIsInvalid
    {
        public SafeMemoryBuffer() : base(true) { }
        public SafeMemoryBuffer(int cb) : base(true)
        {
            base.SetHandle(Marshal.AllocHGlobal(cb));
        }
        public SafeMemoryBuffer(IntPtr handle) : base(true)
        {
            base.SetHandle(handle);
        }

        [ReliabilityContract(Consistency.WillNotCorruptState, Cer.MayFail)]
        protected override bool ReleaseHandle()
        {
            Marshal.FreeHGlobal(handle);
            return true;
        }
    }

    internal class SafeNativeHandle : SafeHandleZeroOrMinusOneIsInvalid
    {
        public SafeNativeHandle() : base(true) { }
        public SafeNativeHandle(IntPtr handle) : base(true) { this.handle = handle; }

        [ReliabilityContract(Consistency.WillNotCorruptState, Cer.MayFail)]
        protected override bool ReleaseHandle()
        {
            return NativeMethods.CloseHandle(handle);
        }
    }

    public class Win32Exception : System.ComponentModel.Win32Exception
    {
        private string _msg;

        public Win32Exception(string message) : this(Marshal.GetLastWin32Error(), message) { }
        public Win32Exception(int errorCode, string message) : base(errorCode)
        {
            _msg = String.Format("{0} ({1}, Win32ErrorCode {2} - 0x{2:X8})", message, base.Message, errorCode);
        }

        public override string Message { get { return _msg; } }
        public static explicit operator Win32Exception(string message) { return new Win32Exception(message); }
    }

    public class Result
    {
        public string StandardOut { get; internal set; }
        public string StandardError { get; internal set; }
        public uint ExitCode { get; internal set; }
    }

    public class ProcessUtil
    {
        /// <summary>
        /// Parses a command line string into an argv array according to the Windows rules
        /// </summary>
        /// <param name="lpCommandLine">The command line to parse</param>
        /// <returns>An array of arguments interpreted by Windows</returns>
        public static string[] CommandLineToArgv(string lpCommandLine)
        {
            int numArgs;
            using (SafeMemoryBuffer buf = NativeMethods.CommandLineToArgvW(lpCommandLine, out numArgs))
            {
                if (buf.IsInvalid)
                    throw new Win32Exception("Error parsing command line");
                IntPtr[] strptrs = new IntPtr[numArgs];
                Marshal.Copy(buf.DangerousGetHandle(), strptrs, 0, numArgs);
                return strptrs.Select(s => Marshal.PtrToStringUni(s)).ToArray();
            }
        }

        /// <summary>
        /// Creates a process based on the CreateProcess API call.
        /// </summary>
        /// <param name="lpApplicationName">The name of the executable or batch file to execute</param>
        /// <param name="lpCommandLine">The command line to execute, typically this includes lpApplication as the first argument</param>
        /// <param name="lpCurrentDirectory">The full path to the current directory for the process, null will have the same cwd as the calling process</param>
        /// <param name="environment">A dictionary of key/value pairs to define the new process environment</param>
        /// <param name="stdin">A byte array to send over the stdin pipe</param>
        /// <param name="outputEncoding">The character encoding for decoding stdout/stderr output of the process.</param>
        /// <param name="waitChildren">Whether to wait for any children spawned by the process to finished (Server2012 +).</param>
        /// <returns>Result object that contains the command output and return code</returns>
        public static Result CreateProcess(string lpApplicationName, string lpCommandLine, string lpCurrentDirectory,
            IDictionary environment, byte[] stdin, string outputEncoding, bool waitChildren)
        {
            NativeHelpers.ProcessCreationFlags creationFlags = NativeHelpers.ProcessCreationFlags.CREATE_SUSPENDED |
                NativeHelpers.ProcessCreationFlags.CREATE_UNICODE_ENVIRONMENT | 
                NativeHelpers.ProcessCreationFlags.EXTENDED_STARTUPINFO_PRESENT;
            NativeHelpers.PROCESS_INFORMATION pi = new NativeHelpers.PROCESS_INFORMATION();
            NativeHelpers.STARTUPINFOEX si = new NativeHelpers.STARTUPINFOEX();
            si.startupInfo.dwFlags = NativeHelpers.StartupInfoFlags.USESTDHANDLES;

            SafeFileHandle stdoutRead, stdoutWrite, stderrRead, stderrWrite, stdinRead, stdinWrite;
            CreateStdioPipes(si, out stdoutRead, out stdoutWrite, out stderrRead, out stderrWrite, out stdinRead,
                out stdinWrite);
            FileStream stdinStream = new FileStream(stdinWrite, FileAccess.Write);

            // $null from PowerShell ends up as an empty string, we need to convert back as an empty string doesn't
            // make sense for these parameters
            if (lpApplicationName == "")
                lpApplicationName = null;

            if (lpCurrentDirectory == "")
                lpCurrentDirectory = null;

            using (SafeMemoryBuffer lpEnvironment = CreateEnvironmentPointer(environment))
            {
                // Create console with utf-8 CP if no existing console is present
                bool isConsole = false;
                if (NativeMethods.GetConsoleWindow() == IntPtr.Zero)
                {
                    isConsole = NativeMethods.AllocConsole();

                    // Set console input/output codepage to UTF-8
                    NativeMethods.SetConsoleCP(65001);
                    NativeMethods.SetConsoleOutputCP(65001);
                }

                try
                {
                    StringBuilder commandLine = new StringBuilder(lpCommandLine);
                    if (!NativeMethods.CreateProcessW(lpApplicationName, commandLine, IntPtr.Zero, IntPtr.Zero,
                        true, creationFlags, lpEnvironment, lpCurrentDirectory, si, out pi))
                    {
                        throw new Win32Exception("CreateProcessW() failed");
                    }
                }
                finally
                {
                    if (isConsole)
                        NativeMethods.FreeConsole();
                }
            }

            return WaitProcess(stdoutRead, stdoutWrite, stderrRead, stderrWrite, stdinStream, stdin, pi,
                outputEncoding, waitChildren);
        }

        internal static void CreateStdioPipes(NativeHelpers.STARTUPINFOEX si, out SafeFileHandle stdoutRead,
            out SafeFileHandle stdoutWrite, out SafeFileHandle stderrRead, out SafeFileHandle stderrWrite,
            out SafeFileHandle stdinRead, out SafeFileHandle stdinWrite)
        {
            NativeHelpers.SECURITY_ATTRIBUTES pipesec = new NativeHelpers.SECURITY_ATTRIBUTES();
            pipesec.bInheritHandle = true;

            if (!NativeMethods.CreatePipe(out stdoutRead, out stdoutWrite, pipesec, 0))
                throw new Win32Exception("STDOUT pipe setup failed");
            if (!NativeMethods.SetHandleInformation(stdoutRead, NativeHelpers.HandleFlags.INHERIT, 0))
                throw new Win32Exception("STDOUT pipe handle setup failed");

            if (!NativeMethods.CreatePipe(out stderrRead, out stderrWrite, pipesec, 0))
                throw new Win32Exception("STDERR pipe setup failed");
            if (!NativeMethods.SetHandleInformation(stderrRead, NativeHelpers.HandleFlags.INHERIT, 0))
                throw new Win32Exception("STDERR pipe handle setup failed");

            if (!NativeMethods.CreatePipe(out stdinRead, out stdinWrite, pipesec, 0))
                throw new Win32Exception("STDIN pipe setup failed");
            if (!NativeMethods.SetHandleInformation(stdinWrite, NativeHelpers.HandleFlags.INHERIT, 0))
                throw new Win32Exception("STDIN pipe handle setup failed");

            si.startupInfo.hStdOutput = stdoutWrite;
            si.startupInfo.hStdError = stderrWrite;
            si.startupInfo.hStdInput = stdinRead;
        }

        internal static SafeMemoryBuffer CreateEnvironmentPointer(IDictionary environment)
        {
            IntPtr lpEnvironment = IntPtr.Zero;
            if (environment != null && environment.Count > 0)
            {
                StringBuilder environmentString = new StringBuilder();
                foreach (DictionaryEntry kv in environment)
                    environmentString.AppendFormat("{0}={1}\0", kv.Key, kv.Value);
                environmentString.Append('\0');

                lpEnvironment = Marshal.StringToHGlobalUni(environmentString.ToString());
            }
            return new SafeMemoryBuffer(lpEnvironment);
        }

        internal static Result WaitProcess(SafeFileHandle stdoutRead, SafeFileHandle stdoutWrite, SafeFileHandle stderrRead,
            SafeFileHandle stderrWrite, FileStream stdinStream, byte[] stdin, NativeHelpers.PROCESS_INFORMATION pi,
            string outputEncoding, bool waitChildren)
        {
            // Default to using UTF-8 as the output encoding, this should be a sane default for most scenarios.
            outputEncoding = String.IsNullOrEmpty(outputEncoding) ? "utf-8" : outputEncoding;
            Encoding encodingInstance = Encoding.GetEncoding(outputEncoding);

            // If we aren't waiting for child processes we don't care if the below fails
            // Logic to wait for children is from Raymond Chen
            // https://devblogs.microsoft.com/oldnewthing/20130405-00/?p=4743
            using (SafeHandle job = CreateJob(!waitChildren))
            using (SafeHandle ioPort = CreateCompletionPort(!waitChildren))
            {
                // Need to assign the completion port to the job and then assigned the new process to that job.
                if (waitChildren)
                {
                    NativeHelpers.JOBOBJECT_ASSOCIATE_COMPLETION_PORT compPort = new NativeHelpers.JOBOBJECT_ASSOCIATE_COMPLETION_PORT()
                    {
                        CompletionKey = job.DangerousGetHandle(),
                        CompletionPort = ioPort.DangerousGetHandle(),
                    };
                    int compPortSize = Marshal.SizeOf(compPort);

                    using (SafeMemoryBuffer compPortPtr = new SafeMemoryBuffer(compPortSize))
                    {
                        Marshal.StructureToPtr(compPort, compPortPtr.DangerousGetHandle(), false);

                        if (!NativeMethods.SetInformationJobObject(job,
                            NativeHelpers.JobObjectInformationClass.JobObjectAssociateCompletionPortInformation,
                            compPortPtr.DangerousGetHandle(), compPortSize))
                        {
                            throw new Win32Exception("Failed to set job completion port information");
                        }
                    }

                    // Server 2012/Win 8 introduced the ability to nest jobs. Older versions will fail with
                    // ERROR_ACCESS_DENIED but we can't do anything about that except not wait for children.
                    if (!NativeMethods.AssignProcessToJobObject(job, pi.hProcess))
                        throw new Win32Exception("Failed to assign new process to completion watcher job");
                }

                // Start the process and get the output.
                NativeMethods.ResumeThread(pi.hThread);

                FileStream stdoutFS = new FileStream(stdoutRead, FileAccess.Read, 4096);
                StreamReader stdout = new StreamReader(stdoutFS, encodingInstance, true, 4096);
                stdoutWrite.Close();

                FileStream stderrFS = new FileStream(stderrRead, FileAccess.Read, 4096);
                StreamReader stderr = new StreamReader(stderrFS, encodingInstance, true, 4096);
                stderrWrite.Close();

                if (stdin != null)
                    stdinStream.Write(stdin, 0, stdin.Length);
                stdinStream.Close();

                string stdoutStr, stderrStr = null;
                GetProcessOutput(stdout, stderr, out stdoutStr, out stderrStr);
                UInt32 rc = GetProcessExitCode(pi.hProcess);

                if (waitChildren)
                {
                    // If the caller wants to wait for all child processes to finish, we continue to poll the job
                    // until it receives JOB_OBJECT_MSG_ACTIVE_PROCESS_ZERO (4).
                    UInt32 completionCode = 0xFFFFFFFF;
                    UIntPtr completionKey;
                    IntPtr overlapped;

                    while (NativeMethods.GetQueuedCompletionStatus(ioPort.DangerousGetHandle(), out completionCode,
                        out completionKey, out overlapped, 0xFFFFFFFF) && completionCode != 4) { }
                }

                return new Result
                {
                    StandardOut = stdoutStr,
                    StandardError = stderrStr,
                    ExitCode = rc
                };
            }
        }

        internal static void GetProcessOutput(StreamReader stdoutStream, StreamReader stderrStream, out string stdout, out string stderr)
        {
            var sowait = new EventWaitHandle(false, EventResetMode.ManualReset);
            var sewait = new EventWaitHandle(false, EventResetMode.ManualReset);
            string so = null, se = null;
            ThreadPool.QueueUserWorkItem((s) =>
            {
                so = stdoutStream.ReadToEnd();
                sowait.Set();
            });
            ThreadPool.QueueUserWorkItem((s) =>
            {
                se = stderrStream.ReadToEnd();
                sewait.Set();
            });
            foreach (var wh in new WaitHandle[] { sowait, sewait })
                wh.WaitOne();
            stdout = so;
            stderr = se;
        }

        internal static UInt32 GetProcessExitCode(IntPtr processHandle)
        {
            SafeWaitHandle hProcess = new SafeWaitHandle(processHandle, true);
            NativeMethods.WaitForSingleObject(hProcess, 0xFFFFFFFF);

            UInt32 exitCode;
            if (!NativeMethods.GetExitCodeProcess(hProcess, out exitCode))
                throw new Win32Exception("GetExitCodeProcess() failed");
            return exitCode;
        }

        private static SafeHandle CreateJob(bool ignoreErrors)
        {
            SafeNativeHandle job = NativeMethods.CreateJobObjectW(IntPtr.Zero, null);
            if (job.IsInvalid && !ignoreErrors)
                throw new Win32Exception("Failed to create job object");

            return job;
        }

        private static SafeHandle CreateCompletionPort(bool ignoreErrors)
        {
            SafeNativeHandle ioPort = NativeMethods.CreateIoCompletionPort((IntPtr)(-1), IntPtr.Zero,
                UIntPtr.Zero, 1);

            if (ioPort.IsInvalid && !ignoreErrors)
                throw new Win32Exception("Failed to create IoCompletionPort");

            return ioPort;
        }
    }
}
