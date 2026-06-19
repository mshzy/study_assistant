import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../local/shuni_zuiling_local_client.dart';
import '../services/assignment_store.dart';

enum _LoginPlatform { chaoxing, shuniZuiling }

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.store,
    this.addPlatformMode = false,
  });

  final AssignmentStore store;
  final bool addPlatformMode;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _chaoxingAccount = TextEditingController();
  final _chaoxingPassword = TextEditingController();
  final _shuniAccount = TextEditingController();
  final _shuniPassword = TextEditingController();
  final _schoolKeyword = TextEditingController();
  _LoginPlatform _platform = _LoginPlatform.chaoxing;
  ShuniZuilingSchool? _selectedSchool;
  bool _accepted = true;
  bool _loginRequested = false;

  @override
  void dispose() {
    _chaoxingAccount.dispose();
    _chaoxingPassword.dispose();
    _shuniAccount.dispose();
    _shuniPassword.dispose();
    _schoolKeyword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final filteredSchools = _filteredShuniSchools;
        final selectedSchool = _selectedShuniSchool(filteredSchools);
        final canLogin =
            _canLogin(selectedSchool) && _accepted && !widget.store.isLoading;

        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                32,
                widget.addPlatformMode ? 18 : 64,
                32,
                24,
              ),
              children: [
                if (widget.addPlatformMode) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton.filledTonal(
                      tooltip: '返回',
                      onPressed: _goBack,
                      icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                Text(
                  widget.addPlatformMode ? '添加平台账号' : '平台登录',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF17211D),
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.addPlatformMode
                      ? '继续绑定另一个平台，作业会合并到同一个列表。'
                      : '添加学习通或数你最灵账号后，作业会合并提醒。',
                  style: Theme.of(
                    context,
                  )
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: const Color(0xFF8B9290)),
                ),
                const SizedBox(height: 18),
                SegmentedButton<_LoginPlatform>(
                  segments: const [
                    ButtonSegment(
                      value: _LoginPlatform.chaoxing,
                      icon: Icon(Icons.school_outlined),
                      label: Text('学习通'),
                    ),
                    ButtonSegment(
                      value: _LoginPlatform.shuniZuiling,
                      icon: Icon(Icons.calculate_outlined),
                      label: Text('数你最灵'),
                    ),
                  ],
                  selected: {_platform},
                  onSelectionChanged: widget.store.isLoading
                      ? null
                      : (value) {
                          setState(() => _platform = value.single);
                          if (_platform == _LoginPlatform.shuniZuiling) {
                            widget.store.loadShuniZuilingSchools();
                          }
                        },
                ),
                const SizedBox(height: 22),
                if (_platform == _LoginPlatform.chaoxing)
                  _ChaoxingForm(
                    account: _chaoxingAccount,
                    password: _chaoxingPassword,
                    onChanged: () => setState(() {}),
                  )
                else
                  _ShuniZuilingForm(
                    account: _shuniAccount,
                    password: _shuniPassword,
                    schoolKeyword: _schoolKeyword,
                    selectedSchool: selectedSchool,
                    schools: filteredSchools,
                    hasLoadedSchools:
                        widget.store.shuniZuilingSchools.isNotEmpty,
                    onSchoolChanged: (school) =>
                        setState(() => _selectedSchool = school),
                    onChanged: () => setState(() {}),
                  ),
                if (widget.store.error != null) ...[
                  const SizedBox(height: 18),
                  _LoginErrorCard(message: widget.store.error!),
                ],
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
                    onPressed: canLogin ? _login : null,
                    child: widget.store.isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _platform == _LoginPlatform.chaoxing
                                ? '登录学习通'
                                : '登录数你最灵',
                            style: const TextStyle(
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
                        style:
                            TextStyle(color: Color(0xFF68706D), fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _canLogin(ShuniZuilingSchool? selectedSchool) {
    if (_platform == _LoginPlatform.chaoxing) {
      return _chaoxingAccount.text.trim().isNotEmpty &&
          _chaoxingPassword.text.isNotEmpty;
    }
    return _shuniAccount.text.trim().isNotEmpty &&
        _shuniPassword.text.isNotEmpty &&
        selectedSchool != null;
  }

  List<ShuniZuilingSchool> get _filteredShuniSchools {
    final keyword = _schoolKeyword.text.trim().toLowerCase();
    final schools = widget.store.shuniZuilingSchools;
    if (keyword.isEmpty) {
      return schools;
    }
    return schools
        .where(
          (school) =>
              school.name.toLowerCase().contains(keyword) ||
              school.code.toLowerCase().contains(keyword),
        )
        .toList(growable: false);
  }

  ShuniZuilingSchool? _selectedShuniSchool(List<ShuniZuilingSchool> schools) {
    if (schools.isEmpty) {
      return null;
    }
    final selected = _selectedSchool;
    if (selected == null) {
      return schools.first;
    }
    for (final school in schools) {
      if (school.code == selected.code) {
        return school;
      }
    }
    return schools.first;
  }

  Future<void> _login() async {
    _loginRequested = true;
    if (_platform == _LoginPlatform.chaoxing) {
      await widget.store.loginChaoxing(
        account: _chaoxingAccount.text,
        password: _chaoxingPassword.text,
        agreementAccepted: _accepted,
      );
      _goHomeIfLoginSucceeded();
      return;
    }
    final selectedSchool = _selectedShuniSchool(_filteredShuniSchools);
    if (selectedSchool == null) {
      return;
    }
    await widget.store.loginShuniZuiling(
      schoolUserLocalId: _shuniAccount.text,
      password: _shuniPassword.text,
      schoolCode: selectedSchool.code,
      agreementAccepted: _accepted,
    );
    _goHomeIfLoginSucceeded();
  }

  void _goHomeIfLoginSucceeded() {
    if (!mounted || !_loginRequested) {
      return;
    }
    if (widget.store.isAuthenticated) {
      context.go('/assignments');
    }
  }

  void _goBack() {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
      return;
    }
    context.go('/profile');
  }
}

class _LoginErrorCard extends StatelessWidget {
  const _LoginErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChaoxingForm extends StatelessWidget {
  const _ChaoxingForm({
    required this.account,
    required this.password,
    required this.onChanged,
  });

  final TextEditingController account;
  final TextEditingController password;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: account,
          onChanged: (_) => onChanged(),
          textInputAction: TextInputAction.next,
          decoration: _fieldDecoration('账号'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: password,
          onChanged: (_) => onChanged(),
          obscureText: true,
          decoration: _fieldDecoration('密码'),
        ),
      ],
    );
  }
}

class _ShuniZuilingForm extends StatelessWidget {
  const _ShuniZuilingForm({
    required this.account,
    required this.password,
    required this.schoolKeyword,
    required this.selectedSchool,
    required this.schools,
    required this.hasLoadedSchools,
    required this.onSchoolChanged,
    required this.onChanged,
  });

  final TextEditingController account;
  final TextEditingController password;
  final TextEditingController schoolKeyword;
  final ShuniZuilingSchool? selectedSchool;
  final List<ShuniZuilingSchool> schools;
  final bool hasLoadedSchools;
  final ValueChanged<ShuniZuilingSchool?> onSchoolChanged;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const ValueKey('school-keyword'),
          controller: schoolKeyword,
          onChanged: (_) => onChanged(),
          textInputAction: TextInputAction.next,
          decoration: _fieldDecoration('输入学校名称或代码搜索'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<ShuniZuilingSchool>(
          key: ValueKey(selectedSchool?.code ?? 'no-school'),
          initialValue: selectedSchool,
          items: schools
              .map(
                (school) => DropdownMenuItem(
                  value: school,
                  child: Text(
                    school.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: schools.isEmpty
              ? null
              : (school) {
                  onSchoolChanged(school);
                  onChanged();
                },
          decoration: _fieldDecoration(
            schools.isEmpty ? '学校' : '学校',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: account,
          onChanged: (_) => onChanged(),
          textInputAction: TextInputAction.next,
          decoration: _fieldDecoration('学号'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: password,
          onChanged: (_) => onChanged(),
          obscureText: true,
          decoration: _fieldDecoration('密码'),
        ),
        const SizedBox(height: 8),
        Text(
          hasLoadedSchools
              ? schools.isEmpty
                  ? '没有匹配学校，请换个关键字。'
                  : '选择学校后会自动使用对应学校代码登录。'
              : '正在获取学校列表，请稍后重试。',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF68706D),
              ),
        ),
      ],
    );
  }
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
