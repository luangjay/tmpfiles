import 'dart:developer' as dev;
import 'package:nfc_manager/nfc_manager.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:pos/src/utils/nfc_reader_provider.dart';

part 'nfc_session_provider.g.dart';

enum NfcSessionState {
  disabled,
  enabled,
}

@Riverpod(keepAlive: true)
class NfcSession extends _$NfcSession {
  @override
  NfcSessionState build() => NfcSessionState.disabled;

  /// Start listening for tag discovery events using NfcManager
  Future<void> start() async {
    if (state == NfcSessionState.enabled) return;
    dev.log("NFC session started.");
    final isAvailable = await NfcManager.instance.isAvailable();
    if (!isAvailable) throw Exception("NFC feature is unavailable.");
    await NfcManager.instance.startSession(
      onDiscovered: ref.read(nfcReaderProvider.notifier).read,
    );
    state = NfcSessionState.enabled;
  }

  /// Stop listening for tag discovery events
  Future<void> stop() async {
    if (state == NfcSessionState.disabled) return;
    dev.log("NFC session stopped.");
    await NfcManager.instance.stopSession();
    state = NfcSessionState.disabled;
  }

  Future<void> toggle() async {
    await (state == NfcSessionState.disabled ? start() : stop());
  }
}
