import assert from "node:assert";

const AUTH_URL = "http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1";
const RTDB_URL = "http://127.0.0.1:9000";
const NS = "tic-tac-toe-online-91c52-default-rtdb";

async function createPlayer(name) {
  const res = await fetch(`${AUTH_URL}/accounts:signUp?key=test-key`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ returnSecureToken: true })
  });
  if (!res.ok) throw new Error(`Auth create failed: ${res.statusText}`);
  const data = await res.json();
  return { name, uid: data.localId, token: data.idToken };
}

function rtdbUrl(path, token) {
  let url = `${RTDB_URL}/${path}.json?ns=${NS}`;
  if (token) url += `&auth=${token}`;
  return url;
}

async function put(path, data, token) {
  const res = await fetch(rtdbUrl(path, token), {
    method: "PUT",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(data)
  });
  const body = await res.json().catch(() => null);
  return { status: res.status, ok: res.ok, body };
}

async function patch(path, data, token) {
  const res = await fetch(rtdbUrl(path, token), {
    method: "PATCH",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(data)
  });
  const body = await res.json().catch(() => null);
  return { status: res.status, ok: res.ok, body };
}

async function get(path, token) {
  const res = await fetch(rtdbUrl(path, token));
  const body = await res.json().catch(() => null);
  return { status: res.status, ok: res.ok, body };
}

async function runTests() {
  console.log("================================================================================");
  console.log("CRITICAL SECOND-PASS: FIREBASE EMULATOR AUTHORITATIVE SECURITY RULES AUDIT");
  console.log("================================================================================\n");

  const playerX = await createPlayer("PlayerX");
  const playerO = await createPlayer("PlayerO");
  const attacker = await createPlayer("Attacker");
  console.log(`[AUTH] Player X UID:  ${playerX.uid}`);
  console.log(`[AUTH] Player O UID:  ${playerO.uid}`);
  console.log(`[AUTH] Attacker UID:  ${attacker.uid}\n`);

  let legitPassed = 0;
  let attackPassed = 0;
  const failedTests = [];

  function passLegit(title) {
    legitPassed++;
    console.log(`  [PASS - LEGITIMATE] ${title}`);
  }

  function passAttack(title) {
    attackPassed++;
    console.log(`  [PASS - ATTACK REJECTED] ${title}`);
  }

  function fail(title, expected, actual) {
    failedTests.push({ title, expected, actual });
    console.error(`  [FAIL] ${title} -> Expected: ${expected}, Got: ${JSON.stringify(actual)}`);
  }

  console.log("--- PART 1: LEGITIMATE OPERATIONS ACCEPTED ---");

  // 1. Authenticated player creates a valid waiting game
  const g1Id = "game_legit_01";
  const g1Data = {
    gameId: g1Id,
    playerX: playerX.uid,
    playerO: null,
    currentTurn: "X",
    status: "waiting"
  };
  const res1 = await put(`games/${g1Id}`, g1Data, playerX.token);
  if (res1.ok) passLegit("1. Authenticated player creates valid waiting game");
  else fail("1. Authenticated player creates valid waiting game", "200 OK", res1);

  // 2. Valid second player joins private room and game
  const res2 = await patch(`games/${g1Id}`, { playerO: playerO.uid, status: "active" }, playerO.token);
  if (res2.ok) passLegit("2. Valid second player joins and transitions game to active");
  else fail("2. Valid second player joins and transitions game to active", "200 OK", res2);

  // 3. Correct X move succeeds (cell 0, currentTurn -> O)
  let currentGameState = {
    gameId: g1Id,
    playerX: playerX.uid,
    playerO: playerO.uid,
    board: { "0": "X" },
    currentTurn: "O",
    status: "active"
  };
  const res3 = await put(`games/${g1Id}`, currentGameState, playerX.token);
  if (res3.ok) passLegit("3. Correct single-cell move by Player X succeeds (cell 0)");
  else fail("3. Correct single-cell move by Player X succeeds", "200 OK", res3);

  // 4. Correct O move succeeds (cell 4, currentTurn -> X)
  currentGameState = {
    ...currentGameState,
    board: { "0": "X", "4": "O" },
    currentTurn: "X"
  };
  const res4 = await put(`games/${g1Id}`, currentGameState, playerO.token);
  if (res4.ok) passLegit("4. Correct single-cell move by Player O succeeds (cell 4)");
  else fail("4. Correct single-cell move by Player O succeeds", "200 OK", res4);

  // 5. Genuine winning move succeeds (X wins top row [0, 1, 2] through legitimate sequence)
  const gWinId = "game_legit_win";
  await put(`games/${gWinId}`, {
    gameId: gWinId,
    playerX: playerX.uid,
    playerO: playerO.uid,
    currentTurn: "X",
    status: "active"
  }, playerX.token);

  await put(`games/${gWinId}`, {
    gameId: gWinId,
    playerX: playerX.uid,
    playerO: playerO.uid,
    board: { "0": "X" },
    currentTurn: "O",
    status: "active"
  }, playerX.token);

  await put(`games/${gWinId}`, {
    gameId: gWinId,
    playerX: playerX.uid,
    playerO: playerO.uid,
    board: { "0": "X", "3": "O" },
    currentTurn: "X",
    status: "active"
  }, playerO.token);

  await put(`games/${gWinId}`, {
    gameId: gWinId,
    playerX: playerX.uid,
    playerO: playerO.uid,
    board: { "0": "X", "1": "X", "3": "O" },
    currentTurn: "O",
    status: "active"
  }, playerX.token);

  await put(`games/${gWinId}`, {
    gameId: gWinId,
    playerX: playerX.uid,
    playerO: playerO.uid,
    board: { "0": "X", "1": "X", "3": "O", "4": "O" },
    currentTurn: "X",
    status: "active"
  }, playerO.token);

  // Move 5: X at 2 -> Genuine Win
  const res5 = await put(`games/${gWinId}`, {
    gameId: gWinId,
    playerX: playerX.uid,
    playerO: playerO.uid,
    board: { "0": "X", "1": "X", "2": "X", "3": "O", "4": "O" },
    currentTurn: "X",
    status: "finished",
    winner: "X",
    winningCells: [0, 1, 2]
  }, playerX.token);
  if (res5.ok) passLegit("5. Genuine 3-in-a-row winning move by X succeeds with winningCells");
  else fail("5. Genuine winning move by X succeeds", "200 OK", res5);

  // 6. Genuine draw succeeds (full board progression, no 3-in-a-row)
  const gDrawId = "game_legit_draw";
  await put(`games/${gDrawId}`, {
    gameId: gDrawId,
    playerX: playerX.uid,
    playerO: playerO.uid,
    currentTurn: "X",
    status: "active"
  }, playerX.token);

  const drawMoves = [
    { p: playerX, b: { "0": "X" }, turn: "O" },
    { p: playerO, b: { "0": "X", "1": "O" }, turn: "X" },
    { p: playerX, b: { "0": "X", "1": "O", "2": "X" }, turn: "O" },
    { p: playerO, b: { "0": "X", "1": "O", "2": "X", "4": "O" }, turn: "X" },
    { p: playerX, b: { "0": "X", "1": "O", "2": "X", "3": "X", "4": "O" }, turn: "O" },
    { p: playerO, b: { "0": "X", "1": "O", "2": "X", "3": "X", "4": "O", "5": "O" }, turn: "X" },
    { p: playerX, b: { "0": "X", "1": "O", "2": "X", "3": "X", "4": "O", "5": "O", "7": "X" }, turn: "O" },
    { p: playerO, b: { "0": "X", "1": "O", "2": "X", "3": "X", "4": "O", "5": "O", "6": "O", "7": "X" }, turn: "X" },
  ];

  for (const m of drawMoves) {
    await put(`games/${gDrawId}`, {
      gameId: gDrawId,
      playerX: playerX.uid,
      playerO: playerO.uid,
      board: m.b,
      currentTurn: m.turn,
      status: "active"
    }, m.p.token);
  }

  // Final move 9: X plays at 8 -> DRAW!
  const res6 = await put(`games/${gDrawId}`, {
    gameId: gDrawId,
    playerX: playerX.uid,
    playerO: playerO.uid,
    board: { "0": "X", "1": "O", "2": "X", "3": "X", "4": "O", "5": "O", "6": "O", "7": "X", "8": "X" },
    currentTurn: "X",
    status: "finished",
    winner: "Draw"
  }, playerX.token);
  if (res6.ok) passLegit("6. Genuine full-board Draw succeeds with status finished");
  else fail("6. Genuine full-board Draw succeeds", "200 OK", res6);

  // 7. Valid private-room creation and join flow works
  const roomCode = "CD8822";
  const roomData = {
    roomCode: roomCode,
    hostUid: playerX.uid,
    guestUid: null,
    gameId: `game_room_${roomCode}`,
    status: "waiting"
  };
  const roomRes1 = await put(`rooms/${roomCode}`, roomData, playerX.token);
  const roomRes2 = await patch(`rooms/${roomCode}`, { guestUid: playerO.uid, status: "active" }, playerO.token);
  if (roomRes1.ok && roomRes2.ok) passLegit("7. Valid private-room creation and guest joining works");
  else fail("7. Private room creation and joining", "200 OK", { roomRes1, roomRes2 });

  // 8. Valid matchmaking flow works
  const mmWaitRes = await put(`matchmaking_queue/waiting`, { uid: playerX.uid, joinedAt: 2000 }, playerX.token);
  const mmMatchRes = await put(`matchmaking_queue/matches/${playerX.uid}`, { gameId: "game_matched_99" }, playerO.token);
  const mmReadRes = await get(`matchmaking_queue/matches/${playerX.uid}`, playerX.token);
  if (mmWaitRes.ok && mmMatchRes.ok && mmReadRes.ok && mmReadRes.body?.gameId === "game_matched_99") {
    passLegit("8. Matchmaking queue registration, pairing, and notification works");
  } else {
    fail("8. Matchmaking flow", "200 OK", { mmWaitRes, mmMatchRes, mmReadRes });
  }

  // 9. Legitimate Rematch Reset from finished game to active with clean board, turn X, winner null
  const rematchRes = await put(`games/${gWinId}`, {
    gameId: gWinId,
    playerX: playerX.uid,
    playerO: playerO.uid,
    board: null,
    currentTurn: "X",
    status: "active",
    winner: null,
    winningCells: null,
    moveCount: 0
  }, playerX.token);
  if (rematchRes.ok) passLegit("9. Legitimate rematch reset from finished game to active with clean state");
  else fail("9. Legitimate rematch reset", "200 OK", rematchRes);

  console.log("\n--- PART 2: ATTACK OPERATIONS REJECTED BY SECURITY RULES ---");

  // Setup active game baseline for attacks
  const atkGameId = "game_attack_baseline";
  await put(`games/${atkGameId}`, {
    gameId: atkGameId,
    playerX: playerX.uid,
    playerO: playerO.uid,
    currentTurn: "X",
    status: "active"
  }, playerX.token);
  await put(`games/${atkGameId}`, {
    gameId: atkGameId,
    playerX: playerX.uid,
    playerO: playerO.uid,
    board: { "0": "X" },
    currentTurn: "O",
    status: "active"
  }, playerX.token);
  await put(`games/${atkGameId}`, {
    gameId: atkGameId,
    playerX: playerX.uid,
    playerO: playerO.uid,
    board: { "0": "X", "4": "O" },
    currentTurn: "X",
    status: "active"
  }, playerO.token);

  // Attack 1: Unauthenticated game write
  const atk1 = await put("games/atk_unauth", { gameId: "atk_unauth", playerX: "hacker", currentTurn: "X", status: "active" }, null);
  if (atk1.status === 401) passAttack("1. Unauthenticated game write is rejected");
  else fail("1. Unauthenticated game write", "401 Permission Denied", atk1);

  // Attack 2: Overwriting an occupied cell (X tries to overwrite cell 4 which has O)
  const atk2 = await put(`games/${atkGameId}`, {
    gameId: atkGameId,
    playerX: playerX.uid,
    playerO: playerO.uid,
    board: { "0": "X", "4": "X" },
    currentTurn: "O",
    status: "active"
  }, playerX.token);
  if (atk2.status === 401) passAttack("2. Overwriting an occupied cell is rejected");
  else fail("2. Overwriting an occupied cell", "401 Permission Denied", atk2);

  // Attack 3: Writing multiple board cells in one transaction (X writes cells 1 and 2 at once)
  const atk3 = await put(`games/${atkGameId}`, {
    gameId: atkGameId,
    playerX: playerX.uid,
    playerO: playerO.uid,
    board: { "0": "X", "1": "X", "2": "X", "4": "O" },
    currentTurn: "O",
    status: "active"
  }, playerX.token);
  if (atk3.status === 401) passAttack("3. Writing multiple board cells in one transaction is rejected");
  else fail("3. Writing multiple board cells in one transaction", "401 Permission Denied", atk3);

  // Attack 4: Writing opponent's symbol (X writes 'O' instead of 'X')
  const atk4 = await put(`games/${atkGameId}`, {
    gameId: atkGameId,
    playerX: playerX.uid,
    playerO: playerO.uid,
    board: { "0": "X", "1": "O", "4": "O" },
    currentTurn: "O",
    status: "active"
  }, playerX.token);
  if (atk4.status === 401) passAttack("4. Writing opponent's symbol is rejected");
  else fail("4. Writing opponent's symbol", "401 Permission Denied", atk4);

  // Attack 5: Out-of-turn move (currentTurn is X, but Player O writes)
  const atk5 = await put(`games/${atkGameId}`, {
    gameId: atkGameId,
    playerX: playerX.uid,
    playerO: playerO.uid,
    board: { "0": "X", "1": "O", "4": "O" },
    currentTurn: "X",
    status: "active"
  }, playerO.token);
  if (atk5.status === 401) passAttack("5. Out-of-turn move is rejected");
  else fail("5. Out-of-turn move", "401 Permission Denied", atk5);

  // Attack 6: Third-party move (Attacker writes to Player X & O's game)
  const atk6 = await put(`games/${atkGameId}`, {
    gameId: atkGameId,
    playerX: playerX.uid,
    playerO: playerO.uid,
    board: { "0": "X", "1": "X", "4": "O" },
    currentTurn: "O",
    status: "active"
  }, attacker.token);
  if (atk6.status === 401) passAttack("6. Third-party move is rejected");
  else fail("6. Third-party move", "401 Permission Denied", atk6);

  // Attack 7: Fabricated winner without 3-in-a-row
  const atk7 = await put(`games/${atkGameId}`, {
    gameId: atkGameId,
    playerX: playerX.uid,
    playerO: playerO.uid,
    board: { "0": "X", "1": "X", "4": "O" },
    currentTurn: "O",
    winner: "X",
    status: "finished"
  }, playerX.token);
  if (atk7.status === 401) passAttack("7. Fabricated winner without 3-in-a-row is rejected");
  else fail("7. Fabricated winner without 3-in-a-row", "401 Permission Denied", atk7);

  // Attack 8: Fabricated winningCells not matching winning line
  const atkWcId = "game_atk_wc2";
  await put(`games/${atkWcId}`, { gameId: atkWcId, playerX: playerX.uid, playerO: playerO.uid, currentTurn: "X", status: "active" }, playerX.token);
  await put(`games/${atkWcId}`, { gameId: atkWcId, playerX: playerX.uid, playerO: playerO.uid, board: { "0": "X" }, currentTurn: "O", status: "active" }, playerX.token);
  await put(`games/${atkWcId}`, { gameId: atkWcId, playerX: playerX.uid, playerO: playerO.uid, board: { "0": "X", "3": "O" }, currentTurn: "X", status: "active" }, playerO.token);
  await put(`games/${atkWcId}`, { gameId: atkWcId, playerX: playerX.uid, playerO: playerO.uid, board: { "0": "X", "1": "X", "3": "O" }, currentTurn: "O", status: "active" }, playerX.token);
  await put(`games/${atkWcId}`, { gameId: atkWcId, playerX: playerX.uid, playerO: playerO.uid, board: { "0": "X", "1": "X", "3": "O", "4": "O" }, currentTurn: "X", status: "active" }, playerO.token);

  const atk8 = await put(`games/${atkWcId}`, {
    gameId: atkWcId,
    playerX: playerX.uid,
    playerO: playerO.uid,
    board: { "0": "X", "1": "X", "2": "X", "3": "O", "4": "O" },
    currentTurn: "X",
    winner: "X",
    winningCells: [3, 4, 5], // FAKE!
    status: "finished"
  }, playerX.token);
  if (atk8.status === 401) passAttack("8. Fabricated winningCells not matching winning line is rejected");
  else fail("8. Fabricated winningCells", "401 Permission Denied", atk8);

  // Attack 9: Premature Draw before all 9 cells are full
  const atk9 = await put(`games/${atkGameId}`, {
    gameId: atkGameId,
    playerX: playerX.uid,
    playerO: playerO.uid,
    board: { "0": "X", "1": "X", "4": "O" },
    currentTurn: "O",
    winner: "Draw",
    status: "finished"
  }, playerX.token);
  if (atk9.status === 401) passAttack("9. Premature Draw before all 9 cells are full is rejected");
  else fail("9. Premature Draw", "401 Permission Denied", atk9);

  // Attack 10: Premature finished status without a winner
  const atk10 = await put(`games/${atkGameId}`, {
    gameId: atkGameId,
    playerX: playerX.uid,
    playerO: playerO.uid,
    board: { "0": "X", "1": "X", "4": "O" },
    currentTurn: "O",
    winner: null,
    status: "finished"
  }, playerX.token);
  if (atk10.status === 401) passAttack("10. Premature finished status without a winner is rejected");
  else fail("10. Premature finished status", "401 Permission Denied", atk10);

  // Attack 11: Changing playerX UID
  const atk11 = await patch(`games/${atkGameId}`, { playerX: attacker.uid }, playerX.token);
  if (atk11.status === 401) passAttack("11. Mutating playerX UID is rejected");
  else fail("11. Mutating playerX UID", "401 Permission Denied", atk11);

  // Attack 12: Hijacking/changing playerO UID
  const atk12 = await patch(`games/${atkGameId}`, { playerO: attacker.uid }, playerX.token);
  if (atk12.status === 401) passAttack("12. Hijacking/changing playerO UID is rejected");
  else fail("12. Hijacking/changing playerO UID", "401 Permission Denied", atk12);

  // Attack 13: Changing immutable gameId
  const atk13 = await patch(`games/${atkGameId}`, { gameId: "game_hijacked_99" }, playerX.token);
  if (atk13.status === 401) passAttack("13. Changing immutable gameId is rejected");
  else fail("13. Changing immutable gameId", "401 Permission Denied", atk13);

  // Attack 14: Invalid currentTurn value
  const atk14 = await patch(`games/${atkGameId}`, { currentTurn: "INVALID" }, playerX.token);
  if (atk14.status === 401) passAttack("14. Setting invalid currentTurn value is rejected");
  else fail("14. Setting invalid currentTurn value", "401 Permission Denied", atk14);

  // Attack 15: Invalid status value
  const atk15 = await patch(`games/${atkGameId}`, { status: "corrupted_status" }, playerX.token);
  if (atk15.status === 401) passAttack("15. Setting invalid status value is rejected");
  else fail("15. Setting invalid status value", "401 Permission Denied", atk15);

  // Attack 16: Player O changes currentTurn without a move
  const atk16 = await patch(`games/${atkGameId}`, { currentTurn: "O" }, playerO.token);
  if (atk16.status === 401) passAttack("16. Player O changing currentTurn without a move is rejected");
  else fail("16. Player O changing currentTurn without a move", "401 Permission Denied", atk16);

  // Attack 17: Player X changes currentTurn without a move
  const atk17 = await patch(`games/${atkGameId}`, { currentTurn: "O" }, playerX.token);
  if (atk17.status === 401) passAttack("17. Player X changing currentTurn without a move is rejected");
  else fail("17. Player X changing currentTurn without a move", "401 Permission Denied", atk17);

  // Attack 18: Player O changes currentTurn and metadata atomically without a move
  const atk18 = await patch(`games/${atkGameId}`, { currentTurn: "O", moveCount: 5, updatedAt: 9999 }, playerO.token);
  if (atk18.status === 401) passAttack("18. Player O changing currentTurn and metadata atomically without a move is rejected");
  else fail("18. Player O changing currentTurn and metadata atomically", "401 Permission Denied", atk18);

  // Attack 19: Player X changes currentTurn and metadata atomically without a move
  const atk19 = await patch(`games/${atkGameId}`, { currentTurn: "O", moveCount: 5, updatedAt: 9999 }, playerX.token);
  if (atk19.status === 401) passAttack("19. Player X changing currentTurn and metadata atomically without a move is rejected");
  else fail("19. Player X changing currentTurn and metadata atomically", "401 Permission Denied", atk19);

  // Attack 20: Active player changes status from active to waiting
  const atk20 = await patch(`games/${atkGameId}`, { status: "waiting" }, playerX.token);
  if (atk20.status === 401) passAttack("20. Active player changing status from active to waiting is rejected");
  else fail("20. Active player changing status from active to waiting", "401 Permission Denied", atk20);

  // Attack 21: Player changes status to finished without a legitimate winning/draw state
  const atk21 = await patch(`games/${atkGameId}`, { status: "finished" }, playerX.token);
  if (atk21.status === 401) passAttack("21. Player changing status to finished without winner/draw is rejected");
  else fail("21. Player changing status to finished without winner/draw", "401 Permission Denied", atk21);

  // Attack 22: Player clears an active board to all-null/empty mid-game (unauthorized reset)
  const atk22 = await put(`games/${atkGameId}`, {
    gameId: atkGameId,
    playerX: playerX.uid,
    playerO: playerO.uid,
    board: null,
    currentTurn: "X",
    status: "active"
  }, playerX.token);
  if (atk22.status === 401) passAttack("22. Wiping active board to null mid-game is rejected");
  else fail("22. Wiping active board to null mid-game", "401 Permission Denied", atk22);

  // Attack 23: Player changes board and currentTurn inconsistently (places piece at cell 1, but keeps currentTurn: X)
  const atk23 = await put(`games/${atkGameId}`, {
    gameId: atkGameId,
    playerX: playerX.uid,
    playerO: playerO.uid,
    board: { "0": "X", "1": "X", "4": "O" },
    currentTurn: "X", // INCONSISTENT! Must flip to 'O'
    status: "active"
  }, playerX.token);
  if (atk23.status === 401) passAttack("23. Inconsistent board change and unchanged currentTurn is rejected");
  else fail("23. Inconsistent board change and unchanged currentTurn", "401 Permission Denied", atk23);

  // Attack 24: Player changes board and status inconsistently (places non-winning piece but sets status: finished)
  const atk24 = await put(`games/${atkGameId}`, {
    gameId: atkGameId,
    playerX: playerX.uid,
    playerO: playerO.uid,
    board: { "0": "X", "1": "X", "4": "O" },
    currentTurn: "O",
    status: "finished" // INCONSISTENT! No winner
  }, playerX.token);
  if (atk24.status === 401) passAttack("24. Inconsistent board change and premature status finished is rejected");
  else fail("24. Inconsistent board change and premature status finished", "401 Permission Denied", atk24);

  // Attack 25: Player changes board, winner, and winningCells to fabricate a game result
  const atk25 = await put(`games/${atkGameId}`, {
    gameId: atkGameId,
    playerX: playerX.uid,
    playerO: playerO.uid,
    board: { "0": "X", "1": "X", "4": "O" }, // only 0 and 1 are X
    currentTurn: "X",
    status: "finished",
    winner: "X",
    winningCells: [0, 1, 2] // Cell 2 is vacant!
  }, playerX.token);
  if (atk25.status === 401) passAttack("25. Fabricating game result on vacant winning cell is rejected");
  else fail("25. Fabricating game result on vacant winning cell", "401 Permission Denied", atk25);

  // Attack 26: Player changes winner while board remains unchanged
  const atk26 = await patch(`games/${atkGameId}`, { winner: "X", status: "finished" }, playerX.token);
  if (atk26.status === 401) passAttack("26. Mutating winner while board remains unchanged is rejected");
  else fail("26. Mutating winner while board remains unchanged", "401 Permission Denied", atk26);

  // Attack 27: Player changes winningCells while board remains unchanged
  const atk27 = await patch(`games/${atkGameId}`, { winningCells: [0, 1, 2] }, playerX.token);
  if (atk27.status === 401) passAttack("27. Mutating winningCells while board remains unchanged is rejected");
  else fail("27. Mutating winningCells while board remains unchanged", "401 Permission Denied", atk27);

  // Attack 28: Player modifies immutable metadata (playerX) together with an otherwise legitimate move
  const atk28 = await put(`games/${atkGameId}`, {
    gameId: atkGameId,
    playerX: attacker.uid, // HIJACK ATTEMPT DURING LEGIT MOVE!
    playerO: playerO.uid,
    board: { "0": "X", "1": "X", "4": "O" },
    currentTurn: "O",
    status: "active"
  }, playerX.token);
  if (atk28.status === 401) passAttack("28. Modifying immutable playerX together with otherwise legitimate move is rejected");
  else fail("28. Modifying immutable playerX together with legitimate move", "401 Permission Denied", atk28);

  console.log("\n================================================================================");
  console.log("FINAL TEST RESULTS SUMMARY");
  console.log("================================================================================");
  console.log(`Legitimate Operations Passed: ${legitPassed} / 9`);
  console.log(`Attack Operations Rejected:   ${attackPassed} / 28`);
  console.log(`Failed Tests:                 ${failedTests.length}`);

  if (failedTests.length > 0) {
    console.error("\nFAILED TEST DETAILS:", JSON.stringify(failedTests, null, 2));
    process.exit(1);
  } else {
    console.log("\n>>> ALL 37 REAL FIREBASE EMULATOR SECURITY RULES TESTS PASSED! <<<");
    process.exit(0);
  }
}

runTests().catch(err => {
  console.error("FATAL ERROR:", err);
  process.exit(1);
});
