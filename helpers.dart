import 'dart:ffi';

extension StringHelper on String {
  static bool isNullOrEmpty(String str) {
    return str == null || str.isEmpty;
  }
}

// copy of Utf16Conversion extension from win32 package but for ANSI
extension AnsiConversion on Pointer<Uint8> {
  String unpackString(int maxLength) {
    final pathData = cast<Uint8>().asTypedList(maxLength);

    var stringLength = pathData.indexOf(0);
    if (stringLength == -1) {
      stringLength = maxLength;
    }

    return String.fromCharCodes(pathData, 0, stringLength);
  }
}

// quick recode of allocate from ffi/allocation.dart to use zero memory initialization
final DynamicLibrary kernel32 = DynamicLibrary.open("kernel32.dll");

typedef HeapAllocNative_t = Pointer Function(Pointer, Uint32, IntPtr);
typedef HeapAlloc_d = Pointer Function(Pointer, int, int);
final HeapAlloc_d pfnHeapAlloc = kernel32.lookupFunction<HeapAllocNative_t, HeapAlloc_d>("HeapAlloc");

typedef HeapFree_t = Int32 Function(Pointer heap, Uint32 flags, Pointer memory);
typedef HeapFree_d = int Function(Pointer heap, int flags, Pointer memory);
final HeapFree_d pfnHeapFree = kernel32.lookupFunction<HeapFree_t, HeapFree_d>("HeapFree");

typedef GetProcessHeap_t = Pointer Function();
typedef GetProcessHeap_d = Pointer Function();
final GetProcessHeap_t pfnGetProcessHeap = kernel32.lookupFunction<GetProcessHeap_t, GetProcessHeap_d>("GetProcessHeap");

final HEAP_ZERO_MEMORY = 0x00000008;
Pointer<T> zero_allocate<T extends NativeType>({int count = 1}) {
  final int totalSize = count * sizeOf<T>();
  Pointer<T> result = pfnHeapAlloc(pfnGetProcessHeap(), HEAP_ZERO_MEMORY, totalSize).cast();

  if (result.address == 0) {
    return nullptr;
  }

  return result;
}