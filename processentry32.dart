import 'dart:ffi';
import 'package:win32/win32.dart';

import './helpers.dart';

class PROCESSENTRY32 extends Struct {
  @Uint32()
  int dwSize;
  @Uint32()
  int cntUsage;
  @Uint32()
  int th32ProcessID;
  @Uint64()
  int th32DefaultHeapID;
  @Uint32()
  int th32ModuleID;
  @Uint32()
  int cntThreads;
  @Uint32()
  int th32ParentProcessID;
  @Uint32()
  int pcPriClassBase;
  @Uint32()
  int dwFlags;

  String get szExeFile => addressOf.cast<Uint8>().elementAt(44).cast<Uint8>().unpackString(MAX_PATH);

  String toString() => '''PROCESSENTRY32
  dwSize = ${dwSize}
  cntUsage = ${cntUsage}
  th32ProcessID = ${th32ProcessID}
  th32DefaultHeapID = ${th32DefaultHeapID}
  th32ModuleID = ${th32ModuleID}
  cntThreads = ${cntThreads}
  th32ParentProcessID = ${th32ParentProcessID}
  pcPriClassBase = ${pcPriClassBase}
  dwFlags = ${dwFlags}
  szExeFile = ${szExeFile.trim()}
''';

  factory PROCESSENTRY32.allocate() => zero_allocate<Uint8>(count: 304).cast<PROCESSENTRY32>().ref..dwSize = 304;
}