import 'package:finance_frontend/core/views/app_wrapper.dart';
import 'package:finance_frontend/core/storage/hive_bootstrap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finance_frontend/core/provider/providers.dart';
import 'package:finance_frontend/features/settings/presentation/cubits/settings_cubit.dart';
import 'package:finance_frontend/features/settings/presentation/cubits/settings_state.dart';
import 'package:finance_frontend/themes/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveBootstrap.ensureInitialized();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => MyAppState();
}

class MyAppState extends ConsumerState<MyApp> {
  @override
  Widget build(BuildContext context) {
    // Keep your existing Bloc setup and MaterialApp wiring here.
    return MultiBlocProvider(
      providers: [
        BlocProvider<SettingsCubit>(
          create:
              (context) => ref.read(settingsCubitProvider)..checkModeStatus(),
        ),
      ],
      child: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, state) {
          if (state is SettingsInitial) {
            return const MaterialApp(
              home: Scaffold(body: Center(child: CircularProgressIndicator())),
            );
          }
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: AppWrapper(),
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode:
                (state is SettingsStateLight)
                    ? ThemeMode.light
                    : ThemeMode.dark,
          );
        },
      ),
    );
  }
}
