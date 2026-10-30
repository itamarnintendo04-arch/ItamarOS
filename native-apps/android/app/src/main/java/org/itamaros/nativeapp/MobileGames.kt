package org.itamaros.nativeapp

import android.os.SystemClock
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.delay
import kotlin.random.Random

// Native Compose games. None of these games loads a website or requires a network connection.
private val gameTitles = listOf("2048", "Snake", "Memory Match", "Tic-Tac-Toe", "Number Guess",
    "Reaction Test", "Rock Paper Scissors", "Math Sprint", "Word Mix", "Pattern Memory", "Connect Four")

private val gameLogos = mapOf(
    "2048" to "🔢",
    "Snake" to "🐍",
    "Memory Match" to "🧠",
    "Tic-Tac-Toe" to "❎",
    "Number Guess" to "❔",
    "Reaction Test" to "⚡",
    "Rock Paper Scissors" to "✊",
    "Math Sprint" to "➕",
    "Word Mix" to "🔤",
    "Pattern Memory" to "🟡",
    "Connect Four" to "🔴"
)

@Composable
fun MobileGamesHub() {
    var selected by rememberSaveable { mutableStateOf<String?>(null) }
    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Text("ItamarOS Games", style = MaterialTheme.typography.headlineMedium)
        if (selected == null) {
            Text("Choose one of 11 real offline games to play.")
            gameTitles.chunked(2).forEach { row ->
                Row(modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    row.forEach { title ->
                        FilledTonalButton(
                            onClick = { selected = title },
                            modifier = Modifier.weight(1f).heightIn(min = 105.dp),
                            contentPadding = PaddingValues(8.dp)
                        ) {
                            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                Text(gameLogos[title] ?: "🎮",
                                    style = MaterialTheme.typography.headlineLarge)
                                Text(title, style = MaterialTheme.typography.labelMedium, maxLines = 2)
                            }
                        }
                    }
                    if (row.size == 1) Spacer(Modifier.weight(1f))
                }
            }
        } else {
            Button(onClick = { selected = null }) { Text("← All games") }
            Text("${gameLogos[selected] ?: "🎮"}  $selected",
                style = MaterialTheme.typography.titleLarge)
            when (selected) {
                "2048" -> Game2048()
                "Snake" -> SnakeGame()
                "Memory Match" -> MemoryGame()
                "Tic-Tac-Toe" -> TicTacToeGame()
                "Number Guess" -> GuessGame()
                "Reaction Test" -> ReactionGame()
                "Rock Paper Scissors" -> RockPaperScissorsGame()
                "Math Sprint" -> MathGame()
                "Word Mix" -> WordGame()
                "Pattern Memory" -> PatternGame()
                "Connect Four" -> ConnectFourGame()
            }
        }
    }
}

@Composable private fun SavedBest(id: String, current: Int, lowerIsBetter: Boolean = false) {
    val context = LocalContext.current
    val prefs = remember { context.getSharedPreferences("itamaros_games_v2", 0) }
    var best by remember(id) { mutableIntStateOf(prefs.getInt(id, 0)) }
    LaunchedEffect(id, current) {
        if (current > 0 && (best == 0 || if (lowerIsBetter) current < best else current > best)) {
            best = current
            prefs.edit().putInt(id, current).apply()
        }
    }
    Text("Best: ${if (best == 0) "—" else best}", style = MaterialTheme.typography.bodySmall)
}

@Composable private fun BoardGrid(columns: Int, labels: List<String>, onClick: (Int) -> Unit,
                                  disabled: (Int) -> Boolean = { false }) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        labels.indices.chunked(columns).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(4.dp), modifier = Modifier.fillMaxWidth()) {
                row.forEach { i ->
                    OutlinedButton(onClick = { onClick(i) }, enabled = !disabled(i),
                        contentPadding = PaddingValues(2.dp), modifier = Modifier.weight(1f).heightIn(min = 45.dp)) {
                        Text(labels[i], maxLines = 1)
                    }
                }
            }
        }
    }
}

private fun spawn2048(source: List<Int>): List<Int> {
    val b = source.toMutableList()
    val free = b.indices.filter { b[it] == 0 }
    if (free.isNotEmpty()) b[free.random()] = if (Random.nextInt(10) == 0) 4 else 2
    return b
}
private fun new2048(): List<Int> = spawn2048(spawn2048(List(16) { 0 }))
private fun shift2048(board: List<Int>, direction: Int): Pair<List<Int>, Int> {
    val out = board.toMutableList()
    var gain = 0
    repeat(4) { line ->
        val positions = (0..3).map { j ->
            when (direction) {
                0 -> line * 4 + j
                1 -> line * 4 + 3 - j
                2 -> j * 4 + line
                else -> (3 - j) * 4 + line
            }
        }
        val numbers = positions.map { board[it] }.filter { it != 0 }
        val merged = mutableListOf<Int>()
        var i = 0
        while (i < numbers.size) {
            if (i + 1 < numbers.size && numbers[i] == numbers[i + 1]) {
                merged.add(numbers[i] * 2); gain += numbers[i] * 2; i += 2
            } else { merged.add(numbers[i]); i++ }
        }
        positions.forEachIndexed { j, position -> out[position] = merged.getOrElse(j) { 0 } }
    }
    return (if (out == board) out else spawn2048(out)) to gain
}
@Composable private fun Game2048() {
    var board by remember { mutableStateOf(new2048()) }
    var score by remember { mutableIntStateOf(0) }
    Text("Combine identical tiles to reach 2048.")
    BoardGrid(4, board.map { if (it == 0) "·" else it.toString() }, {}, { true })
    Text("Score: $score"); SavedBest("2048", score)
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Button(onClick = { val (b, g) = shift2048(board, 2); board = b; score += g }) { Text("↑") }
        Button(onClick = { val (b, g) = shift2048(board, 0); board = b; score += g }) { Text("←") }
        Button(onClick = { val (b, g) = shift2048(board, 3); board = b; score += g }) { Text("↓") }
        Button(onClick = { val (b, g) = shift2048(board, 1); board = b; score += g }) { Text("→") }
    }
    Button(onClick = { board = new2048(); score = 0 }) { Text("New game") }
}

private fun newFood(snake: List<Pair<Int,Int>>): Pair<Int,Int> {
    val free = (0 until 100).map { it % 10 to it / 10 }.filterNot { it in snake }
    return if (free.isEmpty()) (-1 to -1) else free.random()
}
@Composable private fun SnakeGame() {
    var snake by remember { mutableStateOf(listOf(4 to 5, 3 to 5, 2 to 5)) }
    var food by remember { mutableStateOf(7 to 5) }
    var heading by remember { mutableStateOf(1 to 0) }
    var running by remember { mutableStateOf(false) }
    var over by remember { mutableStateOf(false) }
    var score by remember { mutableIntStateOf(0) }
    LaunchedEffect(running, snake, heading) {
        if (!running || over) return@LaunchedEffect
        delay(350)
        val next = snake.first().first + heading.first to snake.first().second + heading.second
        if (next.first !in 0..9 || next.second !in 0..9 || next in (if (next == food) snake else snake.dropLast(1))) {
            running = false; over = true
        } else {
            val longer = listOf(next) + snake
            snake = if (next == food) longer else longer.dropLast(1)
            if (next == food) { score++; food = newFood(snake); if (food.first < 0) { over = true; running = false } }
        }
    }
    Text("Snake · Score: $score ${if (over) "· Game over" else ""}"); SavedBest("snake", score)
    Column(verticalArrangement = Arrangement.spacedBy(1.dp)) {
        (0..9).forEach { y ->
            Text((0..9).joinToString(" ") { x ->
                when (x to y) { snake.first() -> "🟩"; food -> "🍎"; else -> if ((x to y) in snake) "🟢" else "▫️" }
            }, maxLines = 1)
        }
    }
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        listOf("↑" to (0 to -1), "←" to (-1 to 0), "↓" to (0 to 1), "→" to (1 to 0)).forEach { (symbol, dir) ->
            Button(onClick = { if (dir.first != -heading.first || dir.second != -heading.second) heading = dir }) { Text(symbol) }
        }
    }
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Button(onClick = { if (!over) running = !running }) { Text(if (running) "Pause" else "Start") }
        Button(onClick = { snake = listOf(4 to 5, 3 to 5, 2 to 5); food = 7 to 5; heading = 1 to 0; score = 0; over = false; running = false }) { Text("Restart") }
    }
}

@Composable private fun MemoryGame() {
    val symbols = listOf("🍀","⭐","🎯","🎵","🐱","🚀","🌈","🍎")
    var cards by remember { mutableStateOf((symbols + symbols).shuffled()) }
    var first by remember { mutableIntStateOf(-1) }
    var second by remember { mutableIntStateOf(-1) }
    var matched by remember { mutableStateOf(setOf<Int>()) }
    var moves by remember { mutableIntStateOf(0) }
    LaunchedEffect(first, second) {
        if (first >= 0 && second >= 0) {
            delay(700)
            if (cards[first] == cards[second]) matched = matched + first + second
            first = -1; second = -1
        }
    }
    Text("Find the matching pairs. Moves: $moves")
    if (matched.size == 16) { Text("You matched them all!"); SavedBest("memory-fewest", moves, true) }
    BoardGrid(4, cards.mapIndexed { i, sym -> if (i in matched || i == first || i == second) sym else "❔" },
        { i -> if (i !in matched && i != first && first != -1 && second == -1) { second = i; moves++ }
               else if (first == -1 && i !in matched) first = i },
        { i -> i in matched || i == first || second != -1 })
    Button(onClick = { cards = (symbols + symbols).shuffled(); first = -1; second = -1; matched = emptySet(); moves = 0 }) { Text("New cards") }
}

private fun winner3(b: List<String>): String {
    val lines = listOf(listOf(0,1,2),listOf(3,4,5),listOf(6,7,8),listOf(0,3,6),
        listOf(1,4,7),listOf(2,5,8),listOf(0,4,8),listOf(2,4,6))
    for (line in lines) if (b[line[0]].isNotEmpty() && line.all { b[it] == b[line[0]] }) return b[line[0]]
    return if (b.all { it.isNotEmpty() }) "Draw" else ""
}
@Composable private fun TicTacToeGame() {
    var board by remember { mutableStateOf(List(9) { "" }) }
    var turn by remember { mutableStateOf("X") }
    val winner = winner3(board)
    Text(if (winner.isEmpty()) "Turn: $turn" else "Result: $winner")
    BoardGrid(3, board.map { it.ifEmpty { "·" } }, { i ->
        board = board.toMutableList().also { it[i] = turn }
        turn = if (turn == "X") "O" else "X"
    }, { i -> board[i].isNotEmpty() || winner.isNotEmpty() })
    Button(onClick = { board = List(9) { "" }; turn = "X" }) { Text("Next round") }
}

@Composable private fun GuessGame() {
    var target by remember { mutableIntStateOf(Random.nextInt(1, 101)) }
    var input by remember { mutableStateOf("") }
    var tries by remember { mutableIntStateOf(0) }
    var message by remember { mutableStateOf("Guess a number between 1 and 100.") }
    var solved by remember { mutableStateOf(false) }
    Text(message)
    OutlinedTextField(value = input, onValueChange = { input = it.take(3) }, label = { Text("Your guess (1–100)") },
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number), singleLine = true)
    Button(onClick = {
        val n = input.toIntOrNull()
        if (n == null || n !in 1..100) message = "Enter an integer from 1 to 100."
        else if (!solved) { tries++; message = when { n == target -> { solved = true; "Correct in $tries guesses!" }
            n < target -> "Higher!" else -> "Lower!" } }
    }) { Text("Guess") }
    if (solved) SavedBest("guess-fewest", tries, true)
    Button(onClick = { target = Random.nextInt(1,101); tries = 0; input = ""; solved = false; message = "New number selected." }) { Text("New number") }
}

@Composable private fun ReactionGame() {
    var phase by remember { mutableIntStateOf(0) }
    var started by remember { mutableLongStateOf(0L) }
    var last by remember { mutableIntStateOf(0) }
    LaunchedEffect(phase) { if (phase == 1) { delay(Random.nextLong(1300,3500)); started = SystemClock.elapsedRealtime(); phase = 2 } }
    Text(when (phase) { 0 -> "Tap Start, then wait for GO!"; 1 -> "Wait… don't tap yet"; else -> "GO! TAP NOW" })
    Button(onClick = { when (phase) { 0 -> phase = 1; 1 -> { phase = 0; last = 0 }; else -> { last = (SystemClock.elapsedRealtime() - started).toInt(); phase = 0 } } }) {
        Text(if (phase == 0) "Start" else if (phase == 1) "Too early? Tap to reset" else "TAP!")
    }
    if (last > 0) { Text("Reaction: $last ms"); SavedBest("reaction-ms", last, true) }
}

@Composable private fun RockPaperScissorsGame() {
    var result by remember { mutableStateOf("Pick one.") }
    var wins by remember { mutableIntStateOf(0) }
    val names = listOf("Rock", "Paper", "Scissors")
    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        names.forEachIndexed { mine, name ->
            Button(onClick = {
                val cpu = Random.nextInt(3)
                result = "You: $name · Device: ${names[cpu]} · " +
                    (if (cpu == mine) "Draw" else if ((mine - cpu + 3) % 3 == 1) { wins++; "You win!" } else "Device wins")
            }) { Text(name) }
        }
    }
    Text(result); Text("Wins this session: $wins"); SavedBest("rps-wins", wins)
}

@Composable private fun MathGame() {
    var left by remember { mutableIntStateOf(Random.nextInt(2,30)) }
    var right by remember { mutableIntStateOf(Random.nextInt(1,20)) }
    var answer by remember { mutableStateOf("") }
    var correct by remember { mutableIntStateOf(0) }
    var message by remember { mutableStateOf("Solve the sum.") }
    Text("$left + $right = ?")
    OutlinedTextField(value = answer, onValueChange = { answer = it.take(5) }, label = { Text("Answer") },
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number), singleLine = true)
    Button(onClick = {
        if (answer.toIntOrNull() == left + right) { correct++; message = "Correct!" } else message = "Try the next question."
        left = Random.nextInt(2,30); right = Random.nextInt(1,20); answer = ""
    }) { Text("Submit") }
    Text("$message · Correct: $correct"); SavedBest("math", correct)
}

@Composable private fun WordGame() {
    val words = listOf("planet","rocket","galaxy","puzzle","winter","island","orange","camera","jungle")
    var original by remember { mutableStateOf(words.random()) }
    var scramble by remember { mutableStateOf(original.toList().shuffled().joinToString("")) }
    var answer by remember { mutableStateOf("") }
    var correct by remember { mutableIntStateOf(0) }
    var message by remember { mutableStateOf("Unscramble the English word.") }
    Text("Scrambled: $scramble")
    OutlinedTextField(value = answer, onValueChange = { answer = it.take(32) }, label = { Text("Word") }, singleLine = true)
    Button(onClick = {
        if (answer.trim().equals(original, ignoreCase = true)) {
            correct++; message = "Correct!"; original = words.random(); scramble = original.toList().shuffled().joinToString(""); answer = ""
        } else message = "Not yet. Try again."
    }) { Text("Check") }
    Text("$message · Solved: $correct"); SavedBest("words", correct)
}

@Composable private fun PatternGame() {
    val colors = listOf("🔴","🔵","🟡","🟢")
    var sequence by remember { mutableStateOf(listOf(Random.nextInt(4))) }
    var progress by remember { mutableIntStateOf(0) }
    var showing by remember { mutableStateOf(true) }
    var message by remember { mutableStateOf("Memorize the pattern.") }
    LaunchedEffect(sequence) { showing = true; delay(1700L + sequence.size * 500L); showing = false }
    Text("Level: ${sequence.size}")
    Text(if (showing) sequence.joinToString(" ") { colors[it] } else "Your turn. Repeat the pattern.")
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        colors.forEachIndexed { i, color ->
            Button(enabled = !showing, onClick = {
                if (sequence.getOrNull(progress) == i) {
                    progress++
                    if (progress == sequence.size) { message = "Great! Next level."; progress = 0; sequence = sequence + Random.nextInt(4) }
                } else { message = "Try again. New sequence."; progress = 0; sequence = listOf(Random.nextInt(4)) }
            }) { Text(color) }
        }
    }
    Text(message); SavedBest("pattern", sequence.size - 1)
    Button(onClick = { sequence = listOf(Random.nextInt(4)); progress = 0 }) { Text("Restart") }
}

private fun winner4(board: List<Int>, player: Int): Boolean {
    for (r in 0..5) for (c in 0..6) if (board[r*7+c] == player) {
        for ((dc,dr) in listOf(1 to 0, 0 to 1, 1 to 1, -1 to 1)) {
            if ((0..3).all { t -> (c+t*dc) in 0..6 && (r+t*dr) in 0..5 &&
                        board[(r+t*dr)*7+c+t*dc] == player }) return true
        }
    }
    return false
}
@Composable private fun ConnectFourGame() {
    var board by remember { mutableStateOf(List(42) { 0 }) }
    var player by remember { mutableIntStateOf(1) }
    var winner by remember { mutableStateOf("") }
    Text("Connect Four · ${if (winner.isEmpty()) "Player $player's turn" else winner}")
    Row(horizontalArrangement = Arrangement.spacedBy(2.dp), modifier = Modifier.fillMaxWidth()) {
        repeat(7) { col ->
            OutlinedButton(onClick = {
                val row = (5 downTo 0).firstOrNull { board[it*7+col] == 0 }
                if (row != null) {
                    val next = board.toMutableList(); next[row*7+col] = player; board = next
                    if (winner4(next, player)) winner = "Player $player wins!"
                    else if (next.none { it == 0 }) winner = "Draw"
                    else player = 3-player
                }
            }, enabled = winner.isEmpty() && board[col] == 0,
                modifier = Modifier.weight(1f), contentPadding = PaddingValues(0.dp)) { Text("↓") }
        }
    }
    (0..5).forEach { row ->
        Text((0..6).joinToString(" ") { col ->
            when (board[row*7+col]) { 1 -> "🔴"; 2 -> "🟡"; else -> "⚪" }
        })
    }
    Button(onClick = { board = List(42) { 0 }; player = 1; winner = "" }) { Text("New round") }
}
