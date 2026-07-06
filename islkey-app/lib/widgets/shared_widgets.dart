import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/access_event.dart';
import '../theme.dart';

// ─── Customer logo ────────────────────────────────────────────────────────────

class ISLLogo extends StatelessWidget {
  final String? logoUrl;
  final double height;

  const ISLLogo({super.key, this.logoUrl, this.height = 56});

  @override
  Widget build(BuildContext context) {
    if (logoUrl != null && logoUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: logoUrl!,
        height: height,
        fit: BoxFit.contain,
        errorWidget: (_, __, ___) => _islFallback(),
      );
    }
    return _islFallback();
  }

  Widget _islFallback() {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: ISLTheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'ISLKey',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: ISLTheme.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ─── PIN pad ──────────────────────────────────────────────────────────────────

class PinDisplay extends StatelessWidget {
  final int filledCount;
  final int totalCount;
  final Color colour;

  const PinDisplay({
    super.key,
    required this.filledCount,
    this.totalCount = 6,
    this.colour = ISLTheme.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalCount, (i) {
        final filled = i < filledCount;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? colour : Colors.transparent,
            border: Border.all(
              color: filled ? colour : ISLTheme.textMuted,
              width: 2,
            ),
          ),
        );
      }),
    );
  }
}

class NumericKeypad extends StatelessWidget {
  final void Function(String digit) onDigit;
  final VoidCallback onDelete;
  final Color colour;

  const NumericKeypad({
    super.key,
    required this.onDigit,
    required this.onDelete,
    this.colour = ISLTheme.primary,
  });

  @override
  Widget build(BuildContext context) {
    final digits = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', 'del'],
    ];

    return Column(
      children: digits.map((row) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: row.map((key) {
            if (key.isEmpty) return const SizedBox(width: 80, height: 64);
            return _KeyButton(
              label: key,
              colour: colour,
              onTap: () => key == 'del' ? onDelete() : onDigit(key),
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}

class _KeyButton extends StatelessWidget {
  final String label;
  final Color colour;
  final VoidCallback onTap;

  const _KeyButton({
    required this.label,
    required this.colour,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 80,
        height: 64,
        alignment: Alignment.center,
        child: label == 'del'
            ? Icon(Icons.backspace_outlined, color: colour, size: 24)
            : Text(
                label,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w500,
                  color: colour,
                ),
              ),
      ),
    );
  }
}

// ─── Access event tile ────────────────────────────────────────────────────────

class AccessEventTile extends StatelessWidget {
  final AccessEvent event;

  const AccessEventTile({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final granted = event.isGranted;
    final colour = granted ? ISLTheme.unlockColour : ISLTheme.unlockErrorColour;
    final timeStr = DateFormat('HH:mm').format(event.timestamp);
    final dateStr = DateFormat('d MMM').format(event.timestamp);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colour.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              granted ? Icons.lock_open_rounded : Icons.block_rounded,
              color: colour,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.doorName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color: ISLTheme.textPrimary,
                  ),
                ),
                Text(
                  '${granted ? 'Granted' : 'Denied'} · $dateStr at $timeStr',
                  style: const TextStyle(
                    fontSize: 12,
                    color: ISLTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section heading ──────────────────────────────────────────────────────────

class SectionHeading extends StatelessWidget {
  final String text;

  const SectionHeading(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: ISLTheme.textMuted,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ─── Error banner ─────────────────────────────────────────────────────────────

class ErrorBanner extends StatelessWidget {
  final String message;

  const ErrorBanner(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ISLTheme.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ISLTheme.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: ISLTheme.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: ISLTheme.error, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Pulsing NFC ring ─────────────────────────────────────────────────────────

class PulsingRing extends StatefulWidget {
  final Color colour;
  final double size;

  const PulsingRing({super.key, required this.colour, this.size = 180});

  @override
  State<PulsingRing> createState() => _PulsingRingState();
}

class _PulsingRingState extends State<PulsingRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _scale = Tween<double>(begin: 0.75, end: 1.25).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _opacity = Tween<double>(begin: 0.8, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (_, __) => Transform.scale(
              scale: _scale.value,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.colour.withOpacity(_opacity.value),
                    width: 3,
                  ),
                ),
              ),
            ),
          ),
          Container(
            width: widget.size * 0.6,
            height: widget.size * 0.6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.colour.withOpacity(0.12),
            ),
            child: Icon(
              Icons.nfc_rounded,
              size: widget.size * 0.28,
              color: widget.colour,
            ),
          ),
        ],
      ),
    );
  }
}
