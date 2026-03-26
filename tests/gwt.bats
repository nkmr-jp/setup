#!/usr/bin/env bats
# gwt.zsh テストスイート

setup() {
    load test_helper
    setup_test_repos
    setup_mock_dir
    disable_gh
}

teardown() {
    teardown_test_repos
}

# ============================================================
# Group 1: _gwt_prune() - マージ検出テスト
# ============================================================

@test "prune: 通常マージ済みブランチを削除する" {
    create_feature_branch "feat-merged"
    simulate_normal_merge "feat-merged"
    local wt_path=$(create_worktree "feat-merged")
    backdate_worktree "$wt_path"

    run_gwt _gwt_prune --force

    [ "$status" -eq 0 ]
    [[ "$output" == *"ローカルに取り込み済み"* ]] || [[ "$output" == *"マージ済み検出"* ]]
    [ ! -d "$wt_path" ]
}

@test "prune: スカッシュマージ済みブランチを削除する" {
    create_feature_branch "feat-squash" "squash-file.txt" "squash content"
    simulate_squash_merge "feat-squash"
    local wt_path=$(create_worktree "feat-squash")
    backdate_worktree "$wt_path"

    run_gwt _gwt_prune --force

    [ "$status" -eq 0 ]
    [[ "$output" == *"ローカルに取り込み済み"* ]] || [[ "$output" == *"マージ済み検出"* ]]
    [ ! -d "$wt_path" ]
}

@test "prune: 未マージブランチ（リモート削除のみ）は削除しない" {
    create_feature_branch "feat-unmerged" "unmerged-file.txt" "unmerged content"
    local wt_path=$(create_worktree "feat-unmerged")
    backdate_worktree "$wt_path"

    # リモートブランチのみ削除（マージはしない）
    cd "$TEST_REPO"
    git push origin --delete feat-unmerged >/dev/null 2>&1

    run_gwt _gwt_prune --force

    [ "$status" -eq 0 ]
    [ -d "$wt_path" ]
}

@test "prune: 未コミット変更があるブランチはスキップする" {
    create_feature_branch "feat-dirty"
    simulate_normal_merge "feat-dirty"
    local wt_path=$(create_worktree "feat-dirty")
    backdate_worktree "$wt_path"

    # worktree に未コミットの変更を追加
    echo "dirty change" > "$wt_path/dirty.txt"

    run_gwt _gwt_prune --force

    [ "$status" -eq 0 ]
    [[ "$output" == *"未コミットの変更"* ]]
    [ -d "$wt_path" ]
}

@test "prune: 作成30分未満のブランチはスキップする" {
    create_feature_branch "feat-recent"
    simulate_normal_merge "feat-recent"
    local wt_path=$(create_worktree "feat-recent")
    # backdate しない（作成直後 = 30分未満）

    run_gwt _gwt_prune --force

    [ "$status" -eq 0 ]
    [[ "$output" == *"30分未満のためスキップ"* ]]
    [ -d "$wt_path" ]
}

@test "prune: 保護ブランチ（develop）は削除しない" {
    # develop ブランチを作成
    cd "$TEST_REPO"
    git checkout -b develop main >/dev/null 2>&1
    echo "develop content" > develop.txt
    git add develop.txt
    git commit -m "develop commit" >/dev/null 2>&1
    git push -u origin develop >/dev/null 2>&1
    git checkout main >/dev/null 2>&1

    # develop を main にマージ
    simulate_normal_merge "develop"

    # develop の worktree を作成
    local wt_path=$(create_worktree "develop")
    backdate_worktree "$wt_path"

    run_gwt _gwt_prune --force

    [ "$status" -eq 0 ]
    [ -d "$wt_path" ]
}

@test "prune: ローカルのみのブランチ（リモートなし）は削除しない" {
    cd "$TEST_REPO"
    git checkout -b local-only main >/dev/null 2>&1
    echo "local content" > local.txt
    git add local.txt
    git commit -m "local commit" >/dev/null 2>&1
    # push しない
    git checkout main >/dev/null 2>&1

    local wt_path=$(create_worktree "local-only")
    backdate_worktree "$wt_path"

    run_gwt _gwt_prune --force

    [ "$status" -eq 0 ]
    [ -d "$wt_path" ]
}

@test "prune: gh PR マージ検出フォールバックで検出する" {
    create_feature_branch "feat-gh-merged" "gh-file.txt" "gh content"
    local wt_path=$(create_worktree "feat-gh-merged")
    backdate_worktree "$wt_path"

    # gh モックがマージ済み PR を返す
    create_gh_mock 1

    run_gwt _gwt_prune --force

    [ "$status" -eq 0 ]
    [[ "$output" == *"マージ済み検出"* ]] || [[ "$output" == *"ローカルに取り込み済み"* ]]
    [ ! -d "$wt_path" ]
}

@test "prune: マージ済みworktreeがない場合のメッセージ" {
    run_gwt _gwt_prune --force

    [ "$status" -eq 0 ]
    [[ "$output" == *"マージ済みのworktreeとブランチはありません"* ]]
}

# ============================================================
# Group 2: _gwt_new() - worktree 作成テスト
# ============================================================

@test "new: 正しいパスで worktree を作成する" {
    run_gwt _gwt_new "my-feature"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Worktreeを作成しました"* ]]
    [ -d "$BATS_TEST_TMPDIR/repo-wt-my-feature" ]
}

@test "new: 既存ブランチで worktree を作成する" {
    create_feature_branch "existing-branch"

    run_gwt _gwt_new "existing-branch"

    [ "$status" -eq 0 ]
    [[ "$output" == *"既に存在します"* ]]
    [ -d "$BATS_TEST_TMPDIR/repo-wt-existing-branch" ]
}

@test "new: ブランチ名なしでエラーを返す" {
    run_gwt _gwt_new

    [ "$status" -eq 1 ]
    [[ "$output" == *"ブランチ名を指定してください"* ]]
}

@test "new: git リポジトリ外でエラーを返す" {
    run_gwt_from "$BATS_TEST_TMPDIR" _gwt_new "test-branch"

    [ "$status" -eq 1 ]
    [[ "$output" == *"Gitリポジトリではありません"* ]]
}

@test "new: -wt- サフィックスが重複しない" {
    # まず worktree を作成
    run_gwt _gwt_new "first"
    [ "$status" -eq 0 ]

    local wt_first="$BATS_TEST_TMPDIR/repo-wt-first"
    [ -d "$wt_first" ]

    # worktree 内から別の worktree を作成
    run_gwt_from "$wt_first" _gwt_new "second"
    [ "$status" -eq 0 ]

    # repo-wt-second であること（repo-wt-first-wt-second ではない）
    [ -d "$BATS_TEST_TMPDIR/repo-wt-second" ]
    [ ! -d "$BATS_TEST_TMPDIR/repo-wt-first-wt-second" ]
}

@test "new: ベースブランチを指定して作成する" {
    create_feature_branch "base-branch" "base.txt" "base content"

    run_gwt _gwt_new "derived-branch" "base-branch"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Worktreeを作成しました"* ]]
    [ -d "$BATS_TEST_TMPDIR/repo-wt-derived-branch" ]

    # ベースブランチのファイルが含まれていることを確認
    [ -f "$BATS_TEST_TMPDIR/repo-wt-derived-branch/base.txt" ]
}

# ============================================================
# Group 3: _gwt_quick() - クイック作成テスト
# ============================================================

@test "quick: タイムスタンプ付きブランチ名で作成する" {
    run_gwt _gwt_quick "feature/test"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Worktreeを作成しました"* ]]

    # タイムスタンプパターンのディレクトリが存在することを確認
    local found=$(ls -d "$BATS_TEST_TMPDIR"/repo-wt-feature/test-* 2>/dev/null | head -1)
    [ -n "$found" ]
}

@test "quick: プレフィックスなしでエラーを返す" {
    run_gwt _gwt_quick

    [ "$status" -eq 1 ]
    [[ "$output" == *"プレフィックスを指定してください"* ]]
}

# ============================================================
# Group 4: _gwt_list(), _gwt_status(), _gwt_info()
# ============================================================

@test "list: worktree 一覧を表示する" {
    run_gwt _gwt_new "list-test"

    run_gwt _gwt_list

    [ "$status" -eq 0 ]
    [[ "$output" == *"=== Git Worktrees ==="* ]]
    [[ "$output" == *"list-test"* ]]
}

@test "status: 全 worktree のステータスを表示する" {
    run_gwt _gwt_new "status-test"

    run_gwt _gwt_status

    [ "$status" -eq 0 ]
    [[ "$output" == *"=== Worktree Status ==="* ]]
}

@test "info: 現在の worktree 情報を表示する" {
    # macOS では /var -> /private/var のシンボリックリンクにより
    # pwd と git worktree list のパスが不一致になるため、実パスで cd する
    local real_repo=$(cd "$TEST_REPO" && pwd -P)
    run_gwt_from "$real_repo" _gwt_info

    [ "$status" -eq 0 ]
    [[ "$output" == *"=== Current Worktree Info ==="* ]]
    [[ "$output" == *"main"* ]]
}

@test "info: git リポジトリ外でエラーを返す" {
    run_gwt_from "$BATS_TEST_TMPDIR" _gwt_info

    [ "$status" -eq 1 ]
    [[ "$output" == *"Gitリポジトリではありません"* ]]
}

# ============================================================
# Group 5: gwt() ディスパッチテスト
# ============================================================

@test "dispatch: help コマンドが動作する" {
    run_gwt gwt help

    [ "$status" -eq 0 ]
    [[ "$output" == *"Git Worktree Manager"* ]]
}

@test "dispatch: h エイリアスが動作する" {
    run_gwt gwt h

    [ "$status" -eq 0 ]
    [[ "$output" == *"Git Worktree Manager"* ]]
}

@test "dispatch: 引数なしで help を表示する" {
    run_gwt gwt ""

    [ "$status" -eq 0 ]
    [[ "$output" == *"Git Worktree Manager"* ]]
}

@test "dispatch: 不明なコマンドでエラーを返す" {
    run_gwt gwt "nonexistent"

    [ "$status" -eq 1 ]
    [[ "$output" == *"不明なコマンド"* ]]
}

@test "dispatch: n エイリアスはブランチ名なしでエラーを返す" {
    run_gwt gwt n

    [ "$status" -eq 1 ]
    [[ "$output" == *"ブランチ名を指定してください"* ]]
}

@test "dispatch: q エイリアスはプレフィックスなしでエラーを返す" {
    run_gwt gwt q

    [ "$status" -eq 1 ]
    [[ "$output" == *"プレフィックスを指定してください"* ]]
}
