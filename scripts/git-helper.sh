#!/bin/bash

# Quick Git Commands for Daily Development
echo "🔧 GIT QUICK COMMANDS"
echo "===================="

case "$1" in
    "status")
        echo "📊 Git Status:"
        git status
        ;;
    "add")
        echo "📁 Adding all changes..."
        git add .
        echo "✅ All changes staged"
        ;;
    "commit")
        if [ -z "$2" ]; then
            echo "❌ Please provide a commit message"
            echo "Usage: ./scripts/git-helper.sh commit \"Your commit message\""
        else
            git commit -m "$2"
            echo "✅ Changes committed"
        fi
        ;;
    "push")
        echo "🚀 Pushing to GitHub..."
        git push
        echo "✅ Changes pushed to GitHub"
        ;;
    "pull")
        echo "⬇️  Pulling from GitHub..."
        git pull
        echo "✅ Changes pulled from GitHub"
        ;;
    "sync")
        echo "🔄 Syncing with GitHub (add + commit + push)..."
        git add .
        if [ -z "$2" ]; then
            commit_msg="Update: $(date '+%Y-%m-%d %H:%M:%S')"
        else
            commit_msg="$2"
        fi
        git commit -m "$commit_msg"
        git push
        echo "✅ Project synced with GitHub"
        ;;
    "info")
        echo "📋 Repository Information:"
        echo "========================="
        echo "📍 Remote URL: $(git remote get-url origin 2>/dev/null || echo 'Not configured')"
        echo "🌟 Current Branch: $(git branch --show-current 2>/dev/null || echo 'Not in git repo')"
        echo "👤 User: $(git config user.name) <$(git config user.email)>"
        echo "📊 Status:"
        git status --porcelain | wc -l | xargs echo "   Changed files:"
        echo ""
        ;;
    *)
        echo "🚀 Git Helper Commands:"
        echo "======================"
        echo "  status  - Show git status"
        echo "  add     - Add all changes"
        echo "  commit  - Commit with message: commit \"message\""
        echo "  push    - Push to GitHub"
        echo "  pull    - Pull from GitHub"
        echo "  sync    - Add + commit + push: sync \"message\""
        echo "  info    - Show repository information"
        echo ""
        echo "Examples:"
        echo "  ./scripts/git-helper.sh status"
        echo "  ./scripts/git-helper.sh commit \"Added new feature\""
        echo "  ./scripts/git-helper.sh sync \"Updated documentation\""
        ;;
esac
