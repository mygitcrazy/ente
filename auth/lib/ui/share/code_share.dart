import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:ente_auth/l10n/l10n.dart';
import 'package:ente_auth/models/code.dart';
import 'package:ente_auth/ui/components/buttons/button_widget.dart';
import 'package:ente_auth/ui/components/models/button_type.dart';
import 'package:ente_auth/utils/dialog_util.dart';
import 'package:ente_auth/utils/share_utils.dart';
import 'package:ente_auth/utils/totp_util.dart';
import 'package:ente_crypto_dart/ente_crypto_dart.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

class ShareCodeDialog extends StatefulWidget {
  final Code code;
  const ShareCodeDialog({super.key, required this.code});

  @override
  State<ShareCodeDialog> createState() => _ShareCodeDialogState();
}

class _ShareCodeDialogState extends State<ShareCodeDialog> {
  final Logger logger = Logger('_ShareCodeDialogState');
  List<int> items = [5, 15, 30, 60];

  String getItemLabel(int min) {
    if (min == 60) return '1 hour';
    if (min > 60) {
      var hour = '${min ~/ 60}';
      if (min % 60 == 0) return '$hour hour';
      var minx = '${min % 60}';
      return '$hour hr $minx min';
    }
    return '$min min';
  }

  int selectedValue = 15;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Share codes'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select the duration for which you want to share codes.',
          ),
          const SizedBox(height: 10),
          DropdownButtonHideUnderline(
            child: DropdownButton2(
              hint: const Text('Select an option'),
              items: items
                  .map(
                    (item) => DropdownMenuItem<int>(
                      value: item,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(getItemLabel(item)),
                      ),
                    ),
                  )
                  .toList(),
              value: selectedValue,
              onChanged: (value) {
                setState(() {
                  selectedValue = value ?? 15;
                });
              },
            ),
          ),
        ],
      ),
      actions: [
        ButtonWidget(
          buttonType: ButtonType.primary,
          buttonSize: ButtonSize.large,
          labelText: context.l10n.share,
          onTap: () async {
            try {
              await shareCode();
              Navigator.of(context).pop();
            } catch (e) {
              logger.warning('Failed to share code: ${e.toString()}');
              showGenericErrorDialog(context: context, error: e).ignore();
            }
          },
        ),
        const SizedBox(height: 8),
        ButtonWidget(
          buttonType: ButtonType.secondary,
          buttonSize: ButtonSize.large,
          labelText: context.l10n.cancel,
          onTap: () async {
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }

  Future<void> shareCode() async {
    final result = generateFutureTotpCodes(widget.code, 30);
    Map<String, dynamic> data = {
      'startTime': result.$1,
      'step': widget.code.period,
      'codes': result.$2.join(","),
    };
    try {
      final Uint8List key = _generate256BitKey();
      Uint8List input = utf8.encode(jsonEncode(data));
      final encResult = await CryptoUtil.encryptData(input, key);
      String url =
          'https://auth.ente.io/share?data=${_uint8ListToUrlSafeBase64(encResult.encryptedData!)}&header=${_uint8ListToUrlSafeBase64(encResult.header!)}#${_uint8ListToUrlSafeBase64(key)}';
      shareText(url, context: context).ignore();
    } catch (e) {
      logger.severe('Failed to encrypt data: ${e.toString()}');
      await showGenericErrorDialog(context: context, error: e);
    }
  }

  String _uint8ListToUrlSafeBase64(Uint8List data) {
    String base64Str = base64UrlEncode(data);
    return base64Str.replaceAll('=', '');
  }

  Uint8List _generate256BitKey() {
    final random = Random.secure();
    final bytes = Uint8List(32); // 32 bytes = 32 * 8 bits = 256 bits
    for (int i = 0; i < bytes.length; i++) {
      bytes[i] = random
          .nextInt(256); // Generates a random number between 0 and 255 (1 byte)
    }
    return bytes;
  }
}

void showShareDialog(BuildContext context, Code code) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return ShareCodeDialog(
        code: code,
      );
    },
  );
}
