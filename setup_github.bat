@echo off
echo Setting up Git repository...
cd /d "c:\Users\duck1\Desktop\演播室2"

echo Configuring Git user...
git config user.name "Attenna"
git config user.email "george_5298@outlook.com"

echo Checking Git status...
git status

echo Adding all files...
git add .

echo Creating initial commit...
git commit -m "Initial commit: Arknights Theurgy Cup Like Streaming Assistant

- Complete Godot-based streaming assistant for Arknights tournaments
- Player, team, and announcer management systems
- Real-time UI updates with signal-based communication
- Image loading system for player icons, team logos, operator portraits
- Opening relic display system with detailed descriptions
- Left ID bar with player information display
- Score tracking and team balance management
- Multi-language support (Chinese)
- Apache 2.0 licensed"

echo Adding GitHub remote...
git remote add origin https://github.com/Attenna/Arknights-Theurgy-Cup-Like-Streaming-Assistant.git

echo Setting main branch...
git branch -M main

echo Pushing to GitHub...
git push -u origin main

echo Done! Repository uploaded to GitHub.
pause
