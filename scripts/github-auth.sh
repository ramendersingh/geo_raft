#!/bin/bash

# GitHub Authentication Helper
echo "🔐 GITHUB AUTHENTICATION SETUP"
echo "==============================="

echo ""
echo "Choose your authentication method:"
echo "1. GitHub CLI (recommended)"
echo "2. Personal Access Token"
echo "3. SSH Keys"
echo "4. Just configure and push (will prompt for credentials)"

read -p "Enter your choice (1-4): " choice

case $choice in
    1)
        echo ""
        echo "🚀 Setting up GitHub CLI..."
        if command -v gh &> /dev/null; then
            echo "✅ GitHub CLI is already installed"
            gh auth status || gh auth login
        else
            echo "📦 Installing GitHub CLI..."
            if command -v apt &> /dev/null; then
                # Ubuntu/Debian
                curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
                echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
                sudo apt update
                sudo apt install gh
            else
                echo "Please install GitHub CLI manually: https://cli.github.com/"
                exit 1
            fi
            echo "🔐 Login to GitHub..."
            gh auth login
        fi
        ;;
    2)
        echo ""
        echo "🔑 Personal Access Token Setup"
        echo "==============================="
        echo "1. Go to https://github.com/settings/tokens"
        echo "2. Click 'Generate new token (classic)'"
        echo "3. Give it a name: 'Geo-Fabric Development'"
        echo "4. Select scopes: repo, workflow, write:packages"
        echo "5. Click 'Generate token'"
        echo "6. Copy the token (you won't see it again!)"
        echo ""
        read -p "Enter your Personal Access Token: " -s token
        echo ""
        read -p "Enter your GitHub username: " username
        
        # Configure Git to use token
        repo_url=$(git remote get-url origin 2>/dev/null || echo "")
        if [[ $repo_url == https://github.com/* ]]; then
            new_url=$(echo $repo_url | sed "s|https://github.com/|https://$username:$token@github.com/|")
            git remote set-url origin "$new_url"
            echo "✅ Token configured for repository"
        else
            echo "ℹ️  Token saved. Use it when prompted for password during push."
        fi
        ;;
    3)
        echo ""
        echo "🔐 SSH Keys Setup"
        echo "================="
        echo "1. Generate SSH key:"
        echo "   ssh-keygen -t ed25519 -C \"your_email@example.com\""
        echo "2. Add to SSH agent:"
        echo "   eval \"\$(ssh-agent -s)\""
        echo "   ssh-add ~/.ssh/id_ed25519"
        echo "3. Copy public key:"
        echo "   cat ~/.ssh/id_ed25519.pub"
        echo "4. Add to GitHub: https://github.com/settings/keys"
        echo "5. Test connection:"
        echo "   ssh -T git@github.com"
        echo ""
        read -p "Press Enter when you've completed SSH setup..."
        
        # Convert HTTPS remote to SSH
        repo_url=$(git remote get-url origin 2>/dev/null || echo "")
        if [[ $repo_url == https://github.com/* ]]; then
            ssh_url=$(echo $repo_url | sed 's|https://github.com/|git@github.com:|')
            git remote set-url origin "$ssh_url"
            echo "✅ Remote URL converted to SSH"
        fi
        ;;
    4)
        echo ""
        echo "ℹ️  Using basic authentication - you'll be prompted for credentials during push"
        ;;
    *)
        echo "❌ Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "✅ Authentication setup complete!"
echo ""
echo "🔧 Test your setup:"
echo "==================="
echo "Run: git push -u origin main"
echo ""
echo "If you encounter issues:"
echo "• GitHub CLI: gh auth status"
echo "• Token: Check token permissions"
echo "• SSH: ssh -T git@github.com"
