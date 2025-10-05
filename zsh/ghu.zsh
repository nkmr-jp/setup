#!/bin/zsh

HELP="
Usage: ghu COMMAND [keyword]

Commands:
  search      open github search page.
  init        create local and github repository.
              usage: ghu init REPOSITORY_NAME [editor]
  list        open github repositories page.
  open        open github repository page. if without [keyword] open current dir repository page.
  get         clone with a remote repository and change directory
  workspace   create workspace directory
  ws          list all workspace directories
  wind        create workspace directory and launch windsurf
  rm          remove current directory (only works for directories ending with '-ws*')
  rmall       remove all directories ending with '-ws*'
  rmmrg       remove workspace directories with merged branches
"

# Helper function to display help and return
__ghu_show_help() {
  echo -e $HELP
  return 1
}

# Helper function to create a workspace directory
__ghu_create_workspace() {
  local repo_path=$1

  cd $(ghq root)/github.com/
  local ws_base="${repo_path}-ws"
  local ws_num=1
  while [[ -d "${ws_base}${ws_num}" ]]; do
    ((ws_num++))
  done
  local ws_dir="${ws_base}${ws_num}"
  git clone git@github.com:${repo_path}.git $ws_dir
  cd $(ghq root)/github.com/$ws_dir

  # ブランチ自動生成機能
  # developブランチがあればそこから、なければmain、さらになければmasterから作成
  local branch_prefix="ws/"
  local timestamp=$(date +"%Y%m%d_%H%M%S")
  local new_branch="${branch_prefix}${timestamp}"

  # 優先順位の高い順にブランチを確認
  local base_branches=("develop" "main" "master")
  local base_branch=""

  for branch in "${base_branches[@]}"; do
    if git rev-parse --verify $branch >/dev/null 2>&1 ||
       git rev-parse --verify origin/$branch >/dev/null 2>&1; then
      base_branch=$branch
      echo "ベースブランチとして '$branch' を使用します"
      break
    fi
  done

  if [[ -n "$base_branch" ]]; then
    # リモートブランチが存在するか確認
    if git rev-parse --verify origin/$base_branch >/dev/null 2>&1; then
      git checkout -b $new_branch origin/$base_branch
    else
      git checkout -b $new_branch $base_branch
    fi
    echo "新しいブランチ '$new_branch' を作成しました"
  else
    echo "ブランチの自動生成ができませんでした。develop、main、masterのいずれも見つかりません。"
  fi

  echo $ws_dir
}

ghu() {
  if [[ $# -eq 0 ]]; then
    __ghu_show_help
    return
  fi

  case "$1" in
    search)
      open "https://github.com/search?q=$2"
      ;;
    init)
      if [[ $# -ne 2 ]]; then
        __ghu_show_help
        return
      fi
      cd $(ghq root)/github.com/nkmr-jp
      git init $2
      cd $2
      gh repo create $2 --private --confirm
      git remote add origin "git@github.com:nkmr-jp/$2.git"
      git branch -M main
      echo "# $2" >> README.md
      git add README.md
      git commit -m "first commit"
      git push -u origin main
      gh repo view --web
      if [[ $# -eq 3 ]]; then
        eval "$3 ./"
      fi
      ;;
    list)
      open "https://github.com/$GITHUB_USER_NAME?tab=repositories&q=$2"
      ;;
    open)
      if [[ $# -eq 2 ]]; then
        local name=$2
      else
        local name=$(basename $(pwd))
      fi
      open "https://github.com/$GITHUB_USER_NAME/$name"
      ;;
    get)
      ghq get -p $2
      cd $(ghq root)/github.com/$2
      ;;
    workspace)
      __ghu_create_workspace $2
      ;;
    wind)
      __ghu_create_workspace $2
      wind .
      ;;
    land)
      __ghu_create_workspace $2
      land .
      ;;
    charm)
      __ghu_create_workspace $2
      charm .
      ;;
    rm)
      local prev_dir=$(pwd)
      local dir_name=$(basename $prev_dir)
      if [[ $dir_name == *-ws* ]]; then
        cd ../
        rm -rf $prev_dir
      else
        echo "Error: The rm command is only effective for directories ending with '-ws*'."
        echo "Current directory: $dir_name"
      fi
      ;;
    ws)
      local current_dir=$(pwd)
      cd $(ghq root)/github.com/
      local ws_dirs=($(find . -maxdepth 2 -type d -name "*-ws*" | sort))
      if [[ ${#ws_dirs[@]} -eq 0 ]]; then
        echo "No workspace directories found."
      else
        echo "Found the following workspace directories:"
        for dir in "${ws_dirs[@]}"; do
          echo "  $dir"
        done
      fi
      cd $current_dir
      ;;
    rmmrg)
      local current_dir=$(pwd)
      cd $(ghq root)/github.com/
      local ws_dirs=($(find . -maxdepth 2 -type d -name "*-ws*" | sort))
      if [[ ${#ws_dirs[@]} -eq 0 ]]; then
        echo "No workspace directories found."
        cd $current_dir
        return
      fi

      echo "Checking workspace directories for merged branches..."
      local merged_dirs=()

      for dir in "${ws_dirs[@]}"; do
        echo "Checking $dir..."
        cd "$dir"

        # リポジトリかどうか確認
        if [[ ! -d ".git" ]]; then
          echo "  Not a git repository, skipping."
          cd $(ghq root)/github.com/
          continue
        fi

        # 現在のブランチを取得
        local current_branch=$(git rev-parse --abbrev-ref HEAD)
        if [[ "$current_branch" == "main" || "$current_branch" == "master" || "$current_branch" == "develop" ]]; then
          echo "  On base branch ($current_branch), skipping."
          cd $(ghq root)/github.com/
          continue
        fi

        # リモートの最新情報を取得
        git fetch origin --quiet

        # マージ済みかどうかを確認
        local is_merged=false
        for base in "develop" "main" "master"; do
          if git rev-parse --verify origin/$base >/dev/null 2>&1; then
            if git branch --merged origin/$base | grep -q "* $current_branch"; then
              echo "  Branch '$current_branch' is merged into 'origin/$base'."
              merged_dirs+=("$dir")
              is_merged=true
              break
            fi
          fi
        done

        if [[ "$is_merged" == "false" ]]; then
          echo "  Branch '$current_branch' is not merged yet."
        fi

        cd $(ghq root)/github.com/
      done

      if [[ ${#merged_dirs[@]} -eq 0 ]]; then
        echo "No workspace directories with merged branches found."
      else
        echo "\nFound the following workspace directories with merged branches:"
        for dir in "${merged_dirs[@]}"; do
          echo "  $dir"
        done

        read "confirm?Do you want to remove these directories? [y/N] "
        if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
          for dir in "${merged_dirs[@]}"; do
            echo "Removing $dir..."
            rm -rf "$dir"
          done
          echo "All workspace directories with merged branches have been removed."
        else
          echo "Operation cancelled."
        fi
      fi

      cd $current_dir
      ;;
    rmall)
      local current_dir=$(pwd)
      cd $(ghq root)/github.com/
      local ws_dirs=($(find . -maxdepth 2 -type d -name "*-ws*" | sort))
      if [[ ${#ws_dirs[@]} -eq 0 ]]; then
        echo "No workspace directories found."
      else
        echo "Found the following workspace directories:"
        for dir in "${ws_dirs[@]}"; do
          echo "  $dir"
        done
        read "confirm?Do you want to remove all these directories? [y/N] "
        if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
          for dir in "${ws_dirs[@]}"; do
            echo "Removing $dir..."
            rm -rf $dir
          done
          echo "All workspace directories have been removed."
        else
          echo "Operation cancelled."
        fi
      fi
      cd $current_dir
      ;;
    *)
      __ghu_show_help
      ;;
  esac
}
