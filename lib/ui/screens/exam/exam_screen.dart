import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutterquiz/commons/commons.dart';
import 'package:flutterquiz/core/core.dart';
import 'package:flutterquiz/features/exam/cubits/exam_cubit.dart';
import 'package:flutterquiz/features/profile_management/cubits/user_details_cubit.dart';
import 'package:flutterquiz/features/quiz/models/quiz_type.dart';
import 'package:flutterquiz/features/system_config/cubits/system_config_cubit.dart';
import 'package:flutterquiz/features/system_config/model/answer_mode.dart';
import 'package:flutterquiz/ui/screens/exam/widgets/exam_question_status_bottom_sheet_container.dart';
import 'package:flutterquiz/ui/screens/exam/widgets/exam_timer_container.dart';
import 'package:flutterquiz/ui/screens/quiz/widgets/question_container.dart';
import 'package:flutterquiz/ui/widgets/custom_appbar.dart';
import 'package:flutterquiz/ui/widgets/latex_answer_options_list.dart';
import 'package:flutterquiz/ui/widgets/option_container.dart';
import 'package:flutterquiz/utils/answer_encryption.dart';
import 'package:flutterquiz/utils/extensions.dart';
import 'package:flutterquiz/utils/ui_utils.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:screen_protector/screen_protector.dart';

class ExamScreen extends StatefulWidget {
  const ExamScreen({super.key});

  @override
  State<ExamScreen> createState() => _ExamScreenState();

  static Route<ExamScreen> route(RouteSettings routeSettings) {
    return CupertinoPageRoute(builder: (context) => const ExamScreen());
  }
}

class _ExamScreenState extends State<ExamScreen> with WidgetsBindingObserver {
  final timerKey = GlobalKey<ExamTimerContainerState>();

  late final pageController = PageController();

  Timer? canGiveExamAgainTimer;
  bool canGiveExamAgain = true;

  late int canGiveExamAgainTimeInSeconds = context
      .read<SystemConfigCubit>()
      .resumeExamAfterCloseTimeout;

  bool isExitDialogOpen = false;
  bool userLeftTheExam = false;

  bool showYouLeftTheExam = false;
  bool isExamQuestionStatusBottomSheetOpen = false;
  bool showSecurityWarning = false;
  String securityWarningMessage = '';

  int appMinimizeCount = 0;
  bool isWarningDialogOpen = false;

  int currentQuestionIndex = 0;

  late bool isScreenRecordingInIos = false;

  List<String> iosCapturedScreenshotQuestionIds = [];

  late final bool isExamLatexModeEnabled = context
      .read<SystemConfigCubit>()
      .isLatexEnabled(QuizTypes.exam);

  @override
  void initState() {
    super.initState();

    //wake lock enable so phone will not lock automatically after sometime
    WakelockPlus.enable();

    WidgetsBinding.instance.addObserver(this);

    // Enable security features
    _enableSecurityFeatures();

    // Disable copy/paste
    SystemChannels.textInput.invokeMethod('TextInput.hide');

    //start timer
    Future.delayed(Duration.zero, () {
      timerKey.currentState?.startTimer();
    });
  }

  Future<void> _enableSecurityFeatures() async {
    try {
      // Screenshot and screen recording blocking for both Android & iOS
      await ScreenProtector.protectDataLeakageOn();
      
      // Additional protection with blur for iOS
      if (Platform.isIOS) {
        await ScreenProtector.protectDataLeakageWithBlur();
      }
    } catch (e) {
      debugPrint('Security features error: $e');
    }
  }

  Future<void> _disableSecurityFeatures() async {
    try {
      await ScreenProtector.protectDataLeakageOff();
    } catch (e) {
      debugPrint('Disable security error: $e');
    }
  }

  void iosScreenshotCallback() {
    iosCapturedScreenshotQuestionIds.add(
      context.read<ExamCubit>().getQuestions()[currentQuestionIndex].id!,
    );
  }

  void iosScreenRecordCallback({required bool isRecording}) {
    setState(() => isScreenRecordingInIos = isRecording);
  }

  void setCanGiveExamTimer() {
    canGiveExamAgainTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (canGiveExamAgainTimeInSeconds == 0) {
        timer.cancel();

        //can give exam again false
        canGiveExamAgain = false;

        //show user left the exam
        setState(() => showYouLeftTheExam = true);
        //submit result
        submitResult();
      } else {
        canGiveExamAgainTimeInSeconds--;
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState appState) {
    if (appState == AppLifecycleState.paused) {
      appMinimizeCount++;

      if (appMinimizeCount >= 3) {
        // Third time - Auto submit
        if (!showYouLeftTheExam && !isExitDialogOpen) {
          setState(() {
            showSecurityWarning = true;
            securityWarningMessage = 'Exam auto-submitted! You minimized 3 times.';
          });
          
          Future.delayed(const Duration(seconds: 2), () {
            submitResult();
            if (mounted) {
              Navigator.of(context)
                ..pop()
                ..pop();
            }
          });
        }
      }
      setCanGiveExamTimer();
    } else if (appState == AppLifecycleState.resumed) {
      canGiveExamAgainTimer?.cancel();
      
      // Show warning dialog on resume (for 1st and 2nd time)
      if (appMinimizeCount > 0 && appMinimizeCount < 3 && !isWarningDialogOpen) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            showAppMinimizeWarningDialog();
          }
        });
      }

      if (canGiveExamAgain) {
        canGiveExamAgainTimeInSeconds = context
            .read<SystemConfigCubit>()
            .resumeExamAfterCloseTimeout;
      }
    }
  }

  @override
  void dispose() {
    canGiveExamAgainTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    _disableSecurityFeatures();
    super.dispose();
  }

  void showExamQuestionStatusBottomSheet() {
    isExamQuestionStatusBottomSheetOpen = true;
    showModalBottomSheet<void>(
      isScrollControlled: true,
      elevation: 5,
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: UiUtils.bottomSheetTopRadius,
      ),
      builder: (_) => ExamQuestionStatusBottomSheetContainer(
        navigateToResultScreen: navigateToResultScreen,
        pageController: pageController,
      ),
    ).then((_) => isExamQuestionStatusBottomSheetOpen = false);
  }

  bool hasSubmittedAnswerForCurrentQuestion() {
    return context
        .read<ExamCubit>()
        .getQuestions()[currentQuestionIndex]
        .attempted;
  }

  void submitResult() {
    context.read<ExamCubit>().submitResult(
      capturedQuestionIds: iosCapturedScreenshotQuestionIds,
      rulesViolated: iosCapturedScreenshotQuestionIds.isNotEmpty,
      userId: context.read<UserDetailsCubit>().getUserFirebaseId(),
      totalDuration:
          timerKey.currentState?.secondsTookToCompleteExam().toString() ?? '0',
    );
  }

  void submitAnswer(String submittedAnswerId) {
    final examCubit = context.read<ExamCubit>();
    if (hasSubmittedAnswerForCurrentQuestion()) {
      if (examCubit.canUserSubmitAnswerAgainInExam()) {
        examCubit.updateQuestionWithAnswer(
          examCubit.getQuestions()[currentQuestionIndex].id!,
          submittedAnswerId,
        );
      }
    } else {
      examCubit.updateQuestionWithAnswer(
        examCubit.getQuestions()[currentQuestionIndex].id!,
        submittedAnswerId,
      );
    }
  }

  void navigateToResultScreen() {
    if (isExitDialogOpen) {
      Navigator.of(context).pop();
    }

    if (isExamQuestionStatusBottomSheetOpen) {
      Navigator.of(context).pop();
    }

    submitResult();

    final userFirebaseId = context.read<UserDetailsCubit>().getUserFirebaseId();
    final examCubit = context.read<ExamCubit>();
    Navigator.pushReplacementNamed(
      context,
      Routes.resultComingSoon,
    );

    // Navigator.of(context).pushReplacementNamed(
    //   Routes.result,
    //   arguments: {
    //     'quizType': QuizTypes.exam,
    //     'exam': examCubit.getExam(),
    //     'obtainedMarks': examCubit.obtainedMarks(userFirebaseId),
    //     'timeTakenToCompleteQuiz': timerKey.currentState
    //         ?.secondsTookToCompleteExam()
    //         .toDouble(),
    //     'correctExamAnswers': examCubit.correctAnswers(userFirebaseId),
    //     'incorrectExamAnswers': examCubit.incorrectAnswers(userFirebaseId),
    //     'numberOfPlayer': 1,
    //   },
    // );
  }

  Widget _buildBottomMenu() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.width * UiUtils.hzMarginPct,
        0,
        context.width * UiUtils.hzMarginPct,
        40,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous Button
          Container(
            height: 45,
            width: 45,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .onTertiary
                    .withValues(alpha: 0.2),
              ),
            ),
            margin: const EdgeInsets.only(bottom: 20),
            child: Opacity(
              opacity: currentQuestionIndex != 0 ? 1.0 : 0.5,
              child: IconButton(
                onPressed: () {
                  if (currentQuestionIndex != 0) {
                    pageController.previousPage(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                    );
                  }
                },
                icon: Icon(
                  Icons.arrow_back_ios_new,
                  color: Theme.of(context).colorScheme.onTertiary,
                ),
              ),
            ),
          ),

          // Middle Bottom Sheet Button
          Container(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              color: Theme.of(context).colorScheme.onTertiary,
            ),
            padding: const EdgeInsets.only(left: 42, right: 48),
            child: IconButton(
              onPressed: showExamQuestionStatusBottomSheet,
              icon: Icon(
                Icons.keyboard_arrow_up_rounded,
                color: Theme.of(context).colorScheme.surface,
                size: 40,
              ),
            ),
          ),

          // Next Button
          Container(
            height: 45,
            width: 45,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .onTertiary
                    .withValues(alpha: 0.2),
              ),
            ),
            margin: const EdgeInsets.only(bottom: 20),
            child: Opacity(
              opacity:
              (context.read<ExamCubit>().getQuestions().length - 1) !=
                  currentQuestionIndex
                  ? 1.0
                  : 0.5,
              child: IconButton(
                onPressed: () {
                  if (context.read<ExamCubit>().getQuestions().length - 1 !=
                      currentQuestionIndex) {
                    pageController.nextPage(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                    );
                  }
                },
                icon: Icon(
                  Icons.arrow_forward_ios,
                  color: Theme.of(context).colorScheme.onTertiary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildSecurityWarning() {
    if (showSecurityWarning) {
      return Container(
        width: context.width,
        height: context.height,
        color: Colors.red.withOpacity(0.95),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 100, color: Colors.white),
            const SizedBox(height: 20),
            Text(
              securityWarningMessage,
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    return const SizedBox();
  }

  Widget _buildSecurityIndicators() {
    return Positioned(
      top: 10,
      right: 10,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.security, color: Colors.white, size: 16),
            const SizedBox(width: 4),
            const Icon(Icons.block, color: Colors.white, size: 16),
            const SizedBox(width: 4),
            const Icon(Icons.videocam_off, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildYouLeftTheExam() {
    if (showYouLeftTheExam) {
      return Align(
        child: Container(
          width: context.width,
          height: context.height,
          alignment: Alignment.center,
          color: Theme.of(context).primaryColor.withValues(alpha: 0.5),
          child: AlertDialog(
            content: Text(
              context.tr(youLeftTheExamKey)!,
              style: TextStyle(color: Theme.of(context).colorScheme.onTertiary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  context.tr(okayLbl)!,
                  style: TextStyle(color: Theme.of(context).primaryColor),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox();
  }

  Widget _buildQuestions() {
    return BlocBuilder<ExamCubit, ExamState>(
      bloc: context.read<ExamCubit>(),
      builder: (context, state) {
        if (state is ExamFetchSuccess) {
          return PageView.builder(
            onPageChanged: (index) {
              setState(() => currentQuestionIndex = index);
            },
            controller: pageController,
            itemCount: state.questions.length,
            itemBuilder: (context, index) {
              final correctAnswerId = AnswerEncryption.decryptCorrectAnswer(
                rawKey: context.read<UserDetailsCubit>().getUserFirebaseId(),
                correctAnswer: state.questions[index].correctAnswer!,
              );

              final constraints = BoxConstraints(
                maxWidth: context.width * 0.85,
                maxHeight: context.height * 0.785,
              );

              return SingleChildScrollView(
                child: Column(
                  children: [
                    QuestionContainer(
                      isMathQuestion: isExamLatexModeEnabled,
                      questionColor: Theme.of(context).colorScheme.onTertiary,
                      questionNumber: index + 1,
                      question: state.questions[index],
                    ),
                    const SizedBox(height: 25),
                    if (isExamLatexModeEnabled)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: LatexAnswerOptions(
                          hasSubmittedAnswerForCurrentQuestion:
                              hasSubmittedAnswerForCurrentQuestion,
                          submitAnswer: submitAnswer,
                          answerMode: AnswerMode.noAnswerCorrectness,
                          constraints: constraints,
                          correctAnswerId: correctAnswerId,
                          showAudiencePoll: false,
                          audiencePollPercentages: const [],
                          answerOptions: state.questions[index].answerOptions!,
                          submittedAnswerId:
                              state.questions[index].submittedAnswerId,
                        ),
                      )
                    else
                      ...state.questions[index].answerOptions!.map(
                        (option) => OptionContainer(
                          quizType: QuizTypes.exam,
                          answerMode: AnswerMode.noAnswerCorrectness,
                          showAudiencePoll: false,
                          hasSubmittedAnswerForCurrentQuestion:
                              hasSubmittedAnswerForCurrentQuestion,
                          constraints: constraints,
                          answerOption: option,
                          correctOptionId: correctAnswerId,
                          submitAnswer: submitAnswer,
                          submittedAnswerId:
                              state.questions[index].submittedAnswerId,
                        ),
                      ),
                    const SizedBox(height: 100),
                  ],
                ),
              );
            },
          );
        }

        return const SizedBox();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: showYouLeftTheExam,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;

        onTapBackButton();
      },
      child: Scaffold(
        appBar: QAppBar(
          roundedAppBar: false,
          title: ExamTimerContainer(
            navigateToResultScreen: navigateToResultScreen,
            examDurationInMinutes: int.parse(
              context.read<ExamCubit>().getExam().duration,
            ),
            key: timerKey,
          ),
          onTapBackButton: onTapBackButton,
        ),
        body: WillPopScope(
          onWillPop: () async {
            onTapBackButton();
            return false;
          },
          child: Stack(
            children: [
              _buildQuestions(),
              Align(alignment: Alignment.bottomCenter, child: _buildBottomMenu()),
              _buildYouLeftTheExam(),
              _buildSecurityWarning(),
              _buildSecurityIndicators(),
              if (isScreenRecordingInIos)
                SizedBox(
                  width: context.width,
                  height: context.height,
                  child: const ColoredBox(color: Colors.black),
                ),
            ],
          ),
        ),
      ),
    );
  }
  void showAppMinimizeWarningDialog() {
    if (isWarningDialogOpen) return;

    isWarningDialogOpen = true;

    final remainingWarnings = 3 - appMinimizeCount;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Warning Icon
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.red,
                    size: 40,
                  ),
                ),

                const SizedBox(height: 15),

                // Title
                Text(
                  "Warning ${appMinimizeCount}/3",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),

                const SizedBox(height: 12),

                // Message
                Text(
                  "You minimized the exam app.\n\n"
                      "Remaining warnings: $remainingWarnings\n\n"
                      "Next time your exam will be auto submitted.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onTertiary,
                    fontSize: 15,
                  ),
                ),

                const SizedBox(height: 20),

                // Buttons Row
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          submitResult();
                          Navigator.of(dialogContext).pop();
                          Navigator.of(context)
                            ..pop()
                            ..pop();
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text("Exit Exam"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                          Theme.of(context).primaryColor,
                          padding:
                          const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          "Continue",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ).then((_) => isWarningDialogOpen = false);
  }


  void showExitWarningDialog() {
    if (isExitDialogOpen) return;
    
    isExitDialogOpen = true;
    context
        .showDialog<void>(
          title: context.tr('quizExitTitle'),
          message: context.tr('quizExitLbl'),
          cancelButtonText: context.tr('leaveAnyways'),
          confirmButtonText: context.tr('keepPlaying'),
          onCancel: () {
            submitResult();
            context
              ..shouldPop()
              ..shouldPop();
          },
        )
        .then((_) => isExitDialogOpen = false);
  }

  void onTapBackButton() {
    showExitWarningDialog();
  }
}
