import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../theme/tokens.dart';
import '../services/address_lookup_service.dart';
import 'address_search_field.dart';

/// Opens a dialog letting the user search for and pick a real Malaysian
/// address (via OpenStreetMap Nominatim) or type one freehand, then
/// persists both the address and its resolved state to the Supabase auth
/// user's metadata. Returns the saved result, or null if cancelled.
Future<ResolvedAddress?> showEditServiceAddressDialog(
  BuildContext context, {
  required String initialAddress,
}) {
  return showDialog<ResolvedAddress>(
    context: context,
    builder: (_) => _EditAddressDialog(initialAddress: initialAddress),
  );
}

class _EditAddressDialog extends StatefulWidget {
  final String initialAddress;
  const _EditAddressDialog({required this.initialAddress});

  @override
  State<_EditAddressDialog> createState() => _EditAddressDialogState();
}

class _EditAddressDialogState extends State<_EditAddressDialog> {
  final _fieldKey = GlobalKey<AddressSearchFieldState>();
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    final resolved = await _fieldKey.currentState!.validate(
      onError: (msg) => _error = msg,
    );
    if (resolved == null) {
      setState(() => _saving = false);
      return;
    }

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {
          'service_address': resolved.address,
          'service_state': resolved.state,
        }),
      );
      if (mounted) Navigator.of(context).pop(resolved);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save address: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.location_on_outlined,
              color: AppColors.adminPrimary, size: 20),
          SizedBox(width: 8),
          Text('Service Address'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AddressSearchField(
              key: _fieldKey,
              initialAddress: widget.initialAddress,
              errorText: _error,
            ),
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style:
              FilledButton.styleFrom(backgroundColor: AppColors.adminPrimary),
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
