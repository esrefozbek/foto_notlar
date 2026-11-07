import 'package:flutter/material.dart';
import '../services/security_service.dart';

enum LockScreenMode { setup, unlock, changePin }

class LockScreen extends StatefulWidget {
  final LockScreenMode mode;
  final VoidCallback? onSuccess;
  final bool canCancel;

  const LockScreen({
    super.key,
    required this.mode,
    this.onSuccess,
    this.canCancel = false,
  });

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _enteredPin = '';
  String _firstEnteredPin = ''; // Kurulum veya PIN değiştirirken ilk girilen

  int _setupStep = 0; // 0: Yeni PIN gir, 1: Onayla
  int _changeStep = 0; // 0: Mevcut PIN'i doğrula, 1: Yeni PIN gir, 2: Yeni PIN'i onayla

  String _errorMessage = '';
  bool _isBiometricsAvailable = false;
  bool _isBiometricsEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final available = await SecurityService.isBiometricsAvailable();
    final enabled = await SecurityService.isBiometricsEnabled();

    if (mounted) {
      setState(() {
        _isBiometricsAvailable = available;
        _isBiometricsEnabled = enabled;
      });

      // Kilit açma modundaysak ve parmak izi açıksa otomatik sor
      if (widget.mode == LockScreenMode.unlock && available && enabled) {
        _authenticateBiometric();
      }
    }
  }

  Future<void> _authenticateBiometric() async {
    final success = await SecurityService.authenticateWithBiometrics();
    if (success && mounted) {
      _unlockSuccess();
    }
  }

  void _onNumberTap(int number) {
    if (_enteredPin.length < 4) {
      setState(() {
        _errorMessage = '';
        _enteredPin += number.toString();
      });

      if (_enteredPin.length == 4) {
        _processPin();
      }
    }
  }

  void _onBackspace() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _errorMessage = '';
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      });
    }
  }

  Future<void> _processPin() async {
    final pin = _enteredPin;

    if (widget.mode == LockScreenMode.unlock) {
      final isValid = await SecurityService.verifyPin(pin);
      if (isValid) {
        _unlockSuccess();
      } else {
        setState(() {
          _errorMessage = 'Hatalı PIN kodu! Tekrar deneyin.';
          _enteredPin = '';
        });
      }
    } else if (widget.mode == LockScreenMode.setup) {
      if (_setupStep == 0) {
        setState(() {
          _firstEnteredPin = pin;
          _enteredPin = '';
          _setupStep = 1;
        });
      } else {
        if (pin == _firstEnteredPin) {
          await SecurityService.setPin(pin);
          if (_isBiometricsAvailable && mounted) {
            _askForBiometricsSetup();
          } else {
            _unlockSuccess();
          }
        } else {
          setState(() {
            _errorMessage = 'PIN kodları eşleşmedi! Tekrar deneyin.';
            _enteredPin = '';
            _firstEnteredPin = '';
            _setupStep = 0;
          });
        }
      }
    } else if (widget.mode == LockScreenMode.changePin) {
      if (_changeStep == 0) {
        final isValid = await SecurityService.verifyPin(pin);
        if (isValid) {
          setState(() {
            _enteredPin = '';
            _changeStep = 1;
          });
        } else {
          setState(() {
            _errorMessage = 'Mevcut PIN hatalı!';
            _enteredPin = '';
          });
        }
      } else if (_changeStep == 1) {
        setState(() {
          _firstEnteredPin = pin;
          _enteredPin = '';
          _changeStep = 2;
        });
      } else {
        if (pin == _firstEnteredPin) {
          await SecurityService.setPin(pin);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('PIN kodunuz başarıyla güncellendi.')),
            );
            Navigator.pop(context, true);
          }
        } else {
          setState(() {
            _errorMessage = 'Yeni PIN kodları eşleşmedi!';
            _enteredPin = '';
            _firstEnteredPin = '';
            _changeStep = 1;
          });
        }
      }
    }
  }

  void _askForBiometricsSetup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.fingerprint, color: Colors.deepPurple, size: 28),
            SizedBox(width: 8),
            Text('Parmak İzi ile Giriş'),
          ],
        ),
        content: const Text(
          'Daha hızlı ve pratik giriş yapmak için parmak izinizi kullanmak ister misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _unlockSuccess();
            },
            child: const Text('Şimdilik Hayır'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
            onPressed: () async {
              await SecurityService.setBiometricsEnabled(true);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                _unlockSuccess();
              }
            },
            child: const Text('Evet, Aç', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _unlockSuccess() {
    if (widget.onSuccess != null) {
      widget.onSuccess!();
    } else {
      Navigator.pop(context, true);
    }
  }

  String _getTitle() {
    if (widget.mode == LockScreenMode.unlock) {
      return 'Giriş Yapın';
    } else if (widget.mode == LockScreenMode.setup) {
      return _setupStep == 0 ? 'PIN Kodu Belirleyin' : 'PIN Kodunu Onaylayın';
    } else {
      if (_changeStep == 0) return 'Mevcut PIN Kodu';
      if (_changeStep == 1) return 'Yeni PIN Kodu';
      return 'Yeni PIN Kodunu Onaylayın';
    }
  }

  String _getSubtitle() {
    if (widget.mode == LockScreenMode.unlock) {
      return 'Notlarınıza erişmek için 4 haneli PIN kodunuzu girin';
    } else if (widget.mode == LockScreenMode.setup) {
      return _setupStep == 0
          ? 'Notlarınızı korumak için 4 haneli bir şifre seçin'
          : 'Doğrulamak için belirlediğiniz PIN kodunu tekrar girin';
    } else {
      if (_changeStep == 0) return 'Lütfen önce mevcut PIN kodunuzu girin';
      if (_changeStep == 1) return 'Kullanmak istediğiniz yeni 4 haneli PIN kodunu girin';
      return 'Yeni belirlediğiniz PIN kodunu tekrar girin';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: widget.canCancel
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.black87),
                onPressed: () => Navigator.pop(context, false),
              ),
            )
          : null,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),

                  // Üst İkon
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_outline_rounded,
                      size: 38,
                      color: Colors.deepPurple,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Başlık & Açıklama
                  Text(
                    _getTitle(),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getSubtitle(),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 28),

                  // 4 Nokta (PIN Göstergesi)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      final isFilled = index < _enteredPin.length;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        width: isFilled ? 18 : 14,
                        height: isFilled ? 18 : 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isFilled ? Colors.deepPurple : Colors.grey.shade300,
                          border: isFilled
                              ? Border.all(color: Colors.deepPurple.shade300, width: 2)
                              : null,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),

                  // Hata Mesajı
                  SizedBox(
                    height: 24,
                    child: _errorMessage.isNotEmpty
                        ? Text(
                            _errorMessage,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        : null,
                  ),

                  const Spacer(),

                  // Tuş Takımı
                  _buildKeypad(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    return Column(
      children: [
        for (var row = 0; row < 3; row++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (var col = 1; col <= 3; col++)
                  _buildKeypadButton((row * 3 + col).toString(), onTap: () {
                    _onNumberTap(row * 3 + col);
                  }),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Parmak İzi Butonu (Biyometrik varsa göster)
              _isBiometricsAvailable && _isBiometricsEnabled && widget.mode == LockScreenMode.unlock
                  ? _buildIconButton(
                      Icons.fingerprint,
                      color: Colors.deepPurple,
                      onTap: _authenticateBiometric,
                      tooltip: 'Parmak İzi ile Aç',
                    )
                  : const SizedBox(width: 72, height: 72),

              // 0 Tuşu
              _buildKeypadButton('0', onTap: () => _onNumberTap(0)),

              // Geri Silme Tuşu
              _buildIconButton(
                Icons.backspace_outlined,
                color: Colors.grey.shade700,
                onTap: _onBackspace,
                tooltip: 'Sil',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKeypadButton(String label, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton(
    IconData icon, {
    required Color color,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 72,
        height: 72,
        alignment: Alignment.center,
        child: Icon(icon, size: 28, color: color),
      ),
    );
  }
}
