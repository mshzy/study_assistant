import 'package:flutter/material.dart';

import '../services/assignment_store.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.store});

  final AssignmentStore store;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _account = TextEditingController();
  final _password = TextEditingController();
  bool _accepted = true;

  @override
  Widget build(BuildContext context) {
    final canLogin =
        _account.text.trim().isNotEmpty &&
        _password.text.isNotEmpty &&
        _accepted &&
        !widget.store.isLoading;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(32, 88, 32, 24),
          children: [
            Text(
              '用户登录',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF17211D),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '请使用超星学习通账户登录作业提醒',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF8B9290)),
            ),
            const SizedBox(height: 22),
            TextField(
              controller: _account,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.next,
              decoration: _fieldDecoration('请输入账号'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              onChanged: (_) => setState(() {}),
              obscureText: true,
              decoration: _fieldDecoration('请输入密码'),
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 46,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: canLogin
                      ? const Color(0xFF20B8A4)
                      : const Color(0xFFD6D6D8),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFD6D6D8),
                  disabledForegroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
                onPressed: canLogin
                    ? () => widget.store.loginChaoxing(
                        account: _account.text,
                        password: _password.text,
                        agreementAccepted: _accepted,
                      )
                    : null,
                child: widget.store.isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        '登录',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 22),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => _accepted = !_accepted),
                  child: Icon(
                    _accepted
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: _accepted
                        ? const Color(0xFF20B8A4)
                        : const Color(0xFFB7B7B7),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: '我已阅读并同意 ',
                      children: [
                        TextSpan(
                          text: '服务协议',
                          style: TextStyle(color: Color(0xFF00A78F)),
                        ),
                        TextSpan(text: ' 和 '),
                        TextSpan(
                          text: '隐私协议',
                          style: TextStyle(color: Color(0xFF00A78F)),
                        ),
                      ],
                    ),
                    style: TextStyle(color: Color(0xFF68706D), fontSize: 14),
                  ),
                ),
              ],
            ),
            if (widget.store.error != null) ...[
              const SizedBox(height: 18),
              Text(
                widget.store.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFC6C8CC)),
      filled: true,
      fillColor: const Color(0xFFF7F7F8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: BorderSide.none,
      ),
    );
  }
}
