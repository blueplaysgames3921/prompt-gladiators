import '../../../core/models/models.dart';

/// Holds the resolved prompt strategy and engine behaviour for a given mode.
/// Used by BattleEngine and the lobby screen to set up a battle correctly.
class BattleModeConfig {
  const BattleModeConfig({
    required this.type,
    required this.displayName,
    required this.description,
    required this.systemPromptA,
    required this.systemPromptB,
    required this.roundPromptBuilder,
    required this.responsePromptBuilder,
    this.minRounds = 1,
    this.maxRounds = 20,
    this.defaultRounds = 3,
    this.supportsSpectators = true,
    this.supportsJudge = true,
    this.supportsVoting = true,
    this.supportsApocalypse = true,
    this.requiresAgents = false,
  });

  final BattleType type;
  final String displayName;
  final String description;

  /// Default system prompt injected for fighter A if user leaves it blank.
  final String systemPromptA;

  /// Default system prompt injected for fighter B if user leaves it blank.
  final String systemPromptB;

  /// Builds the opening prompt for a given round from context.
  final String Function(BattleModeContext ctx) roundPromptBuilder;

  /// Builds the prompt when a fighter must respond to an opponent (battlefield).
  final String Function(BattleModeContext ctx)? responsePromptBuilder;

  final int minRounds;
  final int maxRounds;
  final int defaultRounds;
  final bool supportsSpectators;
  final bool supportsJudge;
  final bool supportsVoting;
  final bool supportsApocalypse;
  final bool requiresAgents;
}

class BattleModeContext {
  const BattleModeContext({
    required this.roundNumber,
    required this.totalRounds,
    required this.basePrompt,
    this.opponentLastResponse,
    this.ownLastResponse,
    this.fighterName,
    this.opponentName,
    this.apocalypseLevel = 0,
    this.injectedContext,
  });

  final int roundNumber;
  final int totalRounds;
  final String basePrompt;
  final String? opponentLastResponse;
  final String? ownLastResponse;
  final String? fighterName;
  final String? opponentName;
  final int apocalypseLevel;
  final String? injectedContext;
}

/// All available battle mode configurations.
class BattleModes {
  BattleModes._();

  static const classic = BattleModeConfig(
    type: BattleType.classic,
    displayName: 'Classic',
    description: 'Same prompt, both models respond once. Audience votes the winner.',
    systemPromptA: 'You are Fighter A. Answer the prompt directly, confidently, and as well as you can.',
    systemPromptB: 'You are Fighter B. Answer the prompt directly, confidently, and as well as you can.',
    roundPromptBuilder: _classicPrompt,
    responsePromptBuilder: null,
    defaultRounds: 1,
    minRounds: 1,
    maxRounds: 10,
  );

  static const battlefield = BattleModeConfig(
    type: BattleType.battlefield,
    displayName: 'Battlefield',
    description: 'Multi-round back-and-forth. Models respond to each other.',
    systemPromptA: 'You are Fighter A in a battle of wits. Engage directly with your opponent\'s arguments. Be sharp, concise, and compelling.',
    systemPromptB: 'You are Fighter B in a battle of wits. Engage directly with your opponent\'s arguments. Be sharp, concise, and compelling.',
    roundPromptBuilder: _battlefieldPrompt,
    responsePromptBuilder: _battlefieldResponsePrompt,
    defaultRounds: 5,
    minRounds: 2,
    maxRounds: 20,
  );

  static const agenticSwarm = BattleModeConfig(
    type: BattleType.agenticSwarm,
    displayName: 'Agentic Swarm',
    description: 'Deploy multiple agents per side. Agents use tools and coordinate.',
    systemPromptA: 'You are the lead agent for Team A. Coordinate with your team to produce the best possible answer. Use your tools to research and verify.',
    systemPromptB: 'You are the lead agent for Team B. Coordinate with your team to produce the best possible answer. Use your tools to research and verify.',
    roundPromptBuilder: _agenticPrompt,
    responsePromptBuilder: null,
    defaultRounds: 3,
    minRounds: 1,
    maxRounds: 10,
    requiresAgents: true,
  );

  static const tournament = BattleModeConfig(
    type: BattleType.tournament,
    displayName: 'Tournament',
    description: 'Bracket system with ELO rankings. Models compete across sessions.',
    systemPromptA: 'You are competing in a tournament. Give your best response. Your ELO rating depends on it.',
    systemPromptB: 'You are competing in a tournament. Give your best response. Your ELO rating depends on it.',
    roundPromptBuilder: _classicPrompt,
    responsePromptBuilder: null,
    defaultRounds: 3,
    minRounds: 1,
    maxRounds: 10,
  );

  static const commander = BattleModeConfig(
    type: BattleType.commander,
    displayName: 'Commander',
    description: 'Humans control system prompts live. Strategy and prompt engineering matter.',
    systemPromptA: '', // Commander sets this live
    systemPromptB: '', // Commander sets this live
    roundPromptBuilder: _commanderPrompt,
    responsePromptBuilder: null,
    defaultRounds: 5,
    minRounds: 1,
    maxRounds: 20,
  );

  static BattleModeConfig forType(BattleType type) => switch (type) {
        BattleType.classic => classic,
        BattleType.battlefield => battlefield,
        BattleType.agenticSwarm => agenticSwarm,
        BattleType.tournament => tournament,
        BattleType.commander => commander,
      };

  static const all = [classic, battlefield, agenticSwarm, tournament, commander];
}

// ─── Prompt builders ──────────────────────────────────────────────────────────

String _classicPrompt(BattleModeContext ctx) {
  final parts = <String>[ctx.basePrompt];
  if (ctx.injectedContext != null) {
    parts.add('\n[CONTEXT]: ${ctx.injectedContext}');
  }
  return parts.join('\n');
}

String _battlefieldPrompt(BattleModeContext ctx) {
  if (ctx.roundNumber == 1) return _classicPrompt(ctx);

  final buf = StringBuffer();
  buf.writeln('ROUND ${ctx.roundNumber} of ${ctx.totalRounds}.');
  buf.writeln();
  buf.writeln('ORIGINAL TOPIC: ${ctx.basePrompt}');

  if (ctx.opponentLastResponse != null) {
    buf.writeln();
    buf.writeln(
      '${ctx.opponentName ?? 'Your opponent'} just said:',
    );
    buf.writeln('---');
    buf.writeln(ctx.opponentLastResponse);
    buf.writeln('---');
    buf.writeln();
    buf.writeln('Respond directly. Challenge weak points, build on strong ones, and advance your position.');
  }

  if (ctx.injectedContext != null) {
    buf.writeln();
    buf.writeln('[AUDIENCE INJECTION]: ${ctx.injectedContext}');
  }

  return buf.toString();
}

String _battlefieldResponsePrompt(BattleModeContext ctx) =>
    _battlefieldPrompt(ctx);

String _agenticPrompt(BattleModeContext ctx) {
  final buf = StringBuffer();
  buf.writeln('TASK (Round ${ctx.roundNumber}): ${ctx.basePrompt}');
  buf.writeln();
  buf.writeln(
    'You have access to tools. Use them to produce the most accurate, '
    'thorough, and well-evidenced response possible. '
    'Coordinate with your sub-agents if needed.',
  );
  if (ctx.apocalypseLevel > 0) {
    buf.writeln();
    buf.writeln('[ESCALATION LEVEL ${ctx.apocalypseLevel}]: The stakes are higher. '
        'Be more rigorous, more creative, or more adversarial as needed.');
  }
  if (ctx.injectedContext != null) {
    buf.writeln();
    buf.writeln('[CONTEXT INJECTION]: ${ctx.injectedContext}');
  }
  return buf.toString();
}

String _commanderPrompt(BattleModeContext ctx) {
  // Commander mode — the system prompt is set externally by the Commander role.
  // The round prompt is just the base prompt, as the persona comes from system.
  final buf = StringBuffer();
  buf.writeln(ctx.basePrompt);
  if (ctx.roundNumber > 1 && ctx.opponentLastResponse != null) {
    buf.writeln();
    buf.writeln('Previous response from your opponent:');
    buf.writeln(ctx.opponentLastResponse);
  }
  if (ctx.injectedContext != null) {
    buf.writeln('\n[INJECTION]: ${ctx.injectedContext}');
  }
  return buf.toString();
}
