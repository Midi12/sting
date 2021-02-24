library test;

import 'dart:ffi';
import 'package:ffi/ffi.dart';

typedef MessageBoxNative = Int32 Function(IntPtr hWnd, Pointer<Utf16> lpText, Pointer<Utf16> lpCaption, Int32 uType);
typedef MessageBoxDart = int Function(int hWnd, Pointer<Utf16> lpText, Pointer<Utf16> lpCaption, int uType);

final user32 = DynamicLibrary.open('user32.dll');
final pfnMessageBoxW = user32.lookupFunction<MessageBoxNative, MessageBoxDart>('MessageBoxW');

void messageBox(String message, String caption) => pfnMessageBoxW(0, Utf16.toUtf16(message), Utf16.toUtf16(caption), 0);

void main() {
  messageBox('Hello', 'World');
}