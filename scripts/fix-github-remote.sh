#!/bin/bash

# Fix GitHub Remote and Push
echo "🔧 FIXING GITHUB REMOTE URL"
echo "============================"

echo "Current remote URL: $(git remote get-url origin)"
echo ""

# Remove the invalid remote
git remote remove origin

echo "📝 Now let's add the correct GitHub remote:"
echo ""
echo "Please:"
echo "1. Go to https://github.com/new"
echo "2. Create repository: hyperledger-fabric-geo-consensus"
echo "3. Copy the HTTPS URL (like: https://github.com/ramendersingh/hyperledger-fabric-geo-consensus.git)"
echo ""

read -p "Enter your complete GitHub repository URL: " repo_url

if [[ $repo_url == https://github.com/* ]] || [[ $repo_url == git@github.com:* ]]; then
    git remote add origin "$repo_url"
    echo "✅ Remote origin added: $repo_url"
    
    echo ""
    echo "🚀 Attempting to push to GitHub..."
    
    if git push -u origin main; then
        echo ""
        echo "🎉 SUCCESS! Your geo-aware Hyperledger Fabric project is now on GitHub!"
        echo ""
        echo "🔗 Repository URL: $(echo $repo_url | sed 's/\.git$//')"
        echo ""
        echo "📋 What's included in your repository:"
        echo "   ✅ Enhanced etcdraft consensus algorithm"
        echo "   ✅ Geo-aware smart contracts"
        echo "   ✅ Complete Docker deployment"
        echo "   ✅ Monitoring stack (Prometheus + Grafana)"
        echo "   ✅ Caliper benchmarking suite"
        echo "   ✅ Performance documentation (PDFs)"
        echo "   ✅ VS Code development environment"
        echo ""
        echo "🎯 Next steps:"
        echo "   • Add repository topics: hyperledger, blockchain, fabric, consensus"
        echo "   • Share with your team"
        echo "   • Consider making it public for community contributions"
    else
        echo ""
        echo "❌ Push failed. You might need to authenticate:"
        echo ""
        echo "🔐 Try one of these authentication methods:"
        echo "1. GitHub CLI: gh auth login"
        echo "2. Personal Access Token"
        echo "3. SSH keys"
        echo ""
        echo "Run: ./scripts/github-auth.sh for help"
    fi
else
    echo "❌ Invalid GitHub URL format"
    echo "Expected format: https://github.com/username/repository.git"
fi
