import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/platform_tags.dart';
import 'package:pos/src/utils/credit_card.dart';
import 'package:pos/src/utils/nfc.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'nfc_reader_provider.g.dart';

enum NfcReaderState {
  uninitialized,
  ready,
  processing,
  done,
}

@Riverpod(keepAlive: true)
class _Card extends _$Card {
  @override
  CreditCard? build() => null;

  void setState(CreditCard? card) {
    state = card;
  }
}

@Riverpod(keepAlive: true)
class NfcReader extends _$NfcReader {
  @override
  NfcReaderState build() => NfcReaderState.uninitialized;

  ///
  CreditCard? card() {
    return ref.watch(_cardProvider);
  }

  // NFC reader must be initialized before use
  void initialize() {
    ref.read(_cardProvider.notifier).setState(null);
    state = NfcReaderState.ready;
  }

  /// Create a function that handles the tag discovery event
  Future<void> read(NfcTag tag) async {
    if (state != NfcReaderState.ready) {
      throw Exception('NFC reader is not ready.');
    }
    state = NfcReaderState.processing;

    // Get the IsoDep reference from the tag data
    final isoDep = IsoDep.from(tag);
    if (isoDep == null) {
      throw Exception('IsoDep is not supported.');
    }

    // Connect to the tag
    await isoDep.transceive(data: ppse);

    // Try to identify credit card type
    for (int i = 0; i < aids.length; i++) {
      final aid = aids.values.elementAt(i);
      final key = aids.keys.elementAt(i);

      final aidResponse = await isoDep.transceive(
        data: Uint8List.fromList(
          [0x00, 0xA4, 0x04, 0x00, aid.length, ...aid],
        ),
      );
      final aidResponseStatus = aidResponse.sublist(
        aidResponse.length - 2,
      );

      if (listEquals(aidResponseStatus, [0x90, 0x00])) {
        if (key.contains('VISA')) {
          Uint8List gpoResponse = await isoDep.transceive(data: gpo);
          final card = _extractGpoResponse(gpoResponse);

          ref.read(_cardProvider.notifier).setState(card);
          break;
        }
      }
    }

    state = NfcReaderState.done;
  }

  /// Extract GPO response
  CreditCard _extractGpoResponse(Uint8List data) {
    if (!data.contains(87)) {
      throw Exception("TRACK2 NOT FOUND");
    }
    final track2Start = data.indexOf(87);
    final track2Length = data[track2Start + 1];
    final track2Value =
        data.sublist(track2Start + 2, track2Start + 2 + track2Length);

    String track2Hex = '';
    for (int i = 0; i < track2Value.length; i++) {
      String hex = track2Value[i].toRadixString(16);
      if (hex.length == 1) {
        hex = '0$hex';
      }
      track2Hex += hex;
    }
    dev.log('TRACK2: $track2Hex');

    final panStop = track2Hex.indexOf('d');
    final pan = track2Hex.substring(0, panStop);
    final exp = track2Hex.substring(panStop + 1, panStop + 5);

    return CreditCard(
      pan: pan,
      exp: exp,
    );
  }
}
