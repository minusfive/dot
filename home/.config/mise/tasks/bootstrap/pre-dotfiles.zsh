#!/usr/bin/env zsh
#MISE description="Validate the selected profile before dotfile bootstrap"
#MISE quiet=true
#MISE env={MISE_TASK_RUN_AUTO_INSTALL="false"}
#MISE confirm={message="Apply dotfiles for the `{{ usage.profile }}` profile?", default="no"}
#USAGE flag "-p --profile <profile>" env="MISE_ENV" default="work" {
#USAGE   env_fallback "DOT_PROFILE"
#USAGE   help "Select the profile to apply"
#USAGE   choices {
#USAGE      choice "work" help="Safest profile, default"
#USAGE      choice "personal" help="adds personal resources and configurations"
#USAGE   }
#USAGE }

:
