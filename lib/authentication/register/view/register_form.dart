import 'package:authentication_logic/authentication_logic.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hypnosis_downloads/app/view/common/colors.dart';
import 'package:hypnosis_downloads/app/view/components/ui_views_states.dart';
import 'package:hypnosis_downloads/app/view/widgets/default_buttons.dart';
import 'package:hypnosis_downloads/app/view/widgets/default_input_field.dart';

class RegisterForm extends StatefulWidget {
  const RegisterForm({Key? key}) : super(key: key);

  @override
  State<RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<RegisterForm> {
  bool remember = true;
  String? error;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  @override
  Widget build(BuildContext context) {
    return BlocListener<RegisterWithEmailPasswordCubit, AuthRegisterState>(
      listener: (context, state) {
        if (state is AuthRegisterFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Padding(
                padding: const EdgeInsets.all(12),
                child: IntrinsicHeight(
                  child: Center(
                    child: Text(
                      state.errorMessage,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: ComponentColors.snackBarTextColor),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          );
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _EmailInput(
                controller: _emailController,
                error: error,
              ),
              const SizedBox(height: 16),
              _PasswordInput(
                hintText: 'Password',
                controller: _passwordController,
              ),
              const SizedBox(height: 16),
              _PasswordInput(
                hintText: 'Confirm password',
                controller: _confirmPasswordController,
              ),
            ],
          ),
          BlocBuilder<RegisterWithEmailPasswordCubit, AuthRegisterState>(
            builder: (context, state) {
              if (state is AuthRegisterFailure) {
                return ErrorView(state.errorMessage);
              } else {
                return const SizedBox(height: 32);
              }
            },
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PrimaryButton(
                'Create',
                onTap: () {
                  setState(() {
                    final email = _emailController.text;
                    if (context
                        .read<RegisterWithEmailPasswordCubit>()
                        .isEmailValid(email)) {
                      error = null;
                      TextInput.finishAutofillContext(shouldSave: true);
                      context
                          .read<RegisterWithEmailPasswordCubit>()
                          .registerWithEmailPassword(
                            _emailController.text,
                            _passwordController.text,
                            _confirmPasswordController.text,
                          );
                    } else {
                      error = 'Please enter a valid email address';
                    }
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmailInput extends StatelessWidget {
  const _EmailInput({Key? key, required this.controller, required this.error})
      : super(key: key);

  final TextEditingController controller;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return BlocListener<LoginWithEmailPasswordCubit, AuthState>(
      listener: (context, state) {
        if (state is RegisterSuccess) {
          controller.clear();
        }
      },
      child: DefaultInputField(
        hintText: 'Email',
        controller: controller,
        keyboardType: TextInputType.emailAddress,
        errorText: error,
        autofillHints: const [AutofillHints.email],
      ),
    );
  }
}

class _PasswordInput extends StatefulWidget {
  const _PasswordInput(
      {Key? key, required this.hintText, required this.controller})
      : super(key: key);

  final String hintText;
  final TextEditingController controller;

  @override
  State<_PasswordInput> createState() => _PasswordInputState();
}

class _PasswordInputState extends State<_PasswordInput> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return BlocListener<LoginWithEmailPasswordCubit, AuthState>(
      listener: (context, state) {
        if (state is RegisterSuccess) {
          widget.controller.clear();
        }
      },
      child: DefaultInputField(
        hintText: widget.hintText,
        controller: widget.controller,
        obscureText: _obscure,
        autofillHints: const [AutofillHints.password],
        suffixIcon: IconButton(
          icon: Icon(
            _obscure ? Icons.visibility_off : Icons.visibility,
            color: ComponentColors.defaultIconColor,
          ),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    );
  }
}
