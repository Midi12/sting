import 'dart:io';
import 'dart:ffi';

import 'package:args/args.dart';
import 'package:win32/win32.dart';

import './constants.dart';
import './helpers.dart';
import './processentry32.dart';

ArgResults args;
int main(List<String> arguments) {
  banner();

  final parser = ArgParser()
                 ..addOption(kTargetProcess, abbr: kTargetProcessAbbr)
                 ..addOption(kInjectedModule, abbr: kInjectedModuleAbbr);

  final args = parser.parse(arguments);

  final targetProcess = args[kTargetProcess] as String;
  if (StringHelper.isNullOrEmpty(targetProcess)) {
    print('targetProcess is null or empty');
    return exitCode = -1;
  }

  final injectedModule = args[kInjectedModule] as String;
  if (StringHelper.isNullOrEmpty(injectedModule)) {
    print('injectedModule is null or empty');
    return exitCode = -1;
  }

  if (!injectModule(targetProcess, injectedModule)) {
    print('injectModule() failed');
    return exitCode = -1;
  }

  print('Successfully injected module');

  return exitCode;
}

void banner() {
  print('Sting - a simple dll injector written is Dart\r\n');
}

bool injectModule(String targetProcess, String injectedModuleName) {
  final _pid = findProcessByName(targetProcess);
  if (_pid < 0) {
    print('Cannot find ${targetProcess}');
    return false;
  }

  final moduleExists = FileSystemEntity.typeSync(injectedModuleName) != FileSystemEntityType.notFound;
  if (!moduleExists) {
    print('${injectedModuleName} does not exists on disk');
    return false;
  }

  final injectedModule = new File(injectedModuleName).absolute.path;

  final DESIRED_ACCESS = PROCESS_CREATE_THREAD | PROCESS_QUERY_INFORMATION | PROCESS_VM_OPERATION | PROCESS_VM_WRITE | PROCESS_VM_READ;
  final targetHandle = OpenProcess(DESIRED_ACCESS, 0, _pid);
  if (targetHandle == INVALID_HANDLE_VALUE) {
    print('Failed to open process ${_pid}');
    return false;
  }

  final krnl32 = TEXT('kernel32.dll');
  final hKrnl32 = GetModuleHandle(krnl32);
  if (hKrnl32 == NULL) {
    print('Failed to get ${krnl32} address');
    return false;
  }

  final loadLibraryA = convertToANSIString('LoadLibraryA');
  final LoadLibraryA_addr = GetProcAddress(hKrnl32, loadLibraryA);

  final pfnVirtualAllocEx = kernel32.lookupFunction<
    Pointer Function(IntPtr, Pointer, IntPtr, Uint32, Uint32),
    Pointer Function(int, Pointer, int, int, int)>
    ('VirtualAllocEx');
  final allocMemSize = (injectedModule.length + 1) * sizeOf<Uint8>();
  final allocMemAddress = pfnVirtualAllocEx(targetHandle, nullptr, allocMemSize, MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);

  if (allocMemAddress.address == 0) {
    print('Failed to allocate memory (allocMemAddress = ${allocMemAddress.address})');
  }

  final ansiInjectedModule = convertToANSIString(injectedModule);
  final writeSuccess = WriteProcessMemory(targetHandle, allocMemAddress.cast<Void>(), ansiInjectedModule.cast<Void>(), allocMemSize, nullptr);
  if (writeSuccess != TRUE) {
    print('Failed to write dll path');
  }

  final pfnCreateRemoteThread = kernel32.lookupFunction<
  IntPtr Function(IntPtr, Pointer, IntPtr, Pointer, Pointer, Uint32, Pointer<Uint32>),
  int Function(int, Pointer, int, Pointer, Pointer, int, Pointer<Uint32>)>
  ('CreateRemoteThread');
  final pLoadLibraryA = new Pointer.fromAddress(LoadLibraryA_addr);
  final hThread = pfnCreateRemoteThread(targetHandle, nullptr, 0, pLoadLibraryA, allocMemAddress, 0, nullptr);

  return hThread != 0;
}

final TH32CS_SNAPPROCESS = 0x00000002;
findProcessByName(String targetProcess) {
  var _pid = -1;

  final pfnCreateToolhelp32Snapshot = kernel32.lookupFunction
  <IntPtr Function(Uint32, Uint32),
  int Function(int, int)>
  ('CreateToolhelp32Snapshot');
  
  final pfnProcess32First = kernel32.lookupFunction
  <Uint32 Function(IntPtr, Pointer),
  int Function(int, Pointer)>
  ('Process32First');

  final pfnProcess32Next = kernel32.lookupFunction
  <Uint32 Function(IntPtr, Pointer),
  int Function(int, Pointer)>
  ('Process32Next');

  final hSnap = pfnCreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);

  if (hSnap == INVALID_HANDLE_VALUE) {
    print('Failed to open snapshot');
    return -1;
  }

  final entry = PROCESSENTRY32.allocate();
  final pEntry = new Pointer.fromAddress(entry.addressOf.address);

  if (pfnProcess32First(hSnap, pEntry) != TRUE) {
    print('Failed to fetch first entry');
  }

  do {
    if (entry.szExeFile.toLowerCase() == targetProcess.toLowerCase()) {
      _pid = entry.th32ProcessID;
      break;
    }
  } while( pfnProcess32Next(hSnap, pEntry) == TRUE);

  CloseHandle(hSnap);
  return _pid;
}