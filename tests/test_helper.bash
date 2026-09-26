# shellcheck shell=bash

# Common setup for bats tests.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export REPO_ROOT

# Prefer repo-local bats install from task setup.
if [[ -x "${REPO_ROOT}/.tools/bats/bin/bats" ]]; then
  export PATH="${REPO_ROOT}/.tools/bats/bin:${PATH}"
fi

export PATH="${REPO_ROOT}/bin:${PATH}"

# shellcheck source=../lib/common.sh
source "${REPO_ROOT}/lib/common.sh"
# shellcheck source=../lib/log.sh
source "${REPO_ROOT}/lib/log.sh"
# shellcheck source=../lib/crossover.sh
source "${REPO_ROOT}/lib/crossover.sh"
# shellcheck source=../lib/eso_paths.sh
source "${REPO_ROOT}/lib/eso_paths.sh"
# shellcheck source=../lib/eso_runtime.sh
source "${REPO_ROOT}/lib/eso_runtime.sh"
# shellcheck source=../lib/eso_setup.sh
source "${REPO_ROOT}/lib/eso_setup.sh"
# shellcheck source=../lib/dune_paths.sh
source "${REPO_ROOT}/lib/dune_paths.sh"
# shellcheck source=../lib/dune_battleye.sh
source "${REPO_ROOT}/lib/dune_battleye.sh"
# shellcheck source=../lib/dune_runtime.sh
source "${REPO_ROOT}/lib/dune_runtime.sh"
# shellcheck source=../lib/dune_setup.sh
source "${REPO_ROOT}/lib/dune_setup.sh"

export -f \
  dune_bottle_name \
  dune_ensure_bottle_env \
  dune_steam_exe_path \
  dune_steam_exe_candidates \
  dune_be_wrapper_exe \
  dune_paths_json \
  dune_cxbottle_set_env_var \
  dune_host_is_apple_silicon \
  crossover_open_app \
  crossover_repo_root \
  crossover_ties_dir \
  crossover_tie_path \
  crossover_run_wine \
  crossover_wineboot_end \
  crossover_wineserver_kill \
  crossover_bottle_kill_host_procs \
  crossover_taskkill \
  crossover_bottle_process_lines \
  crossover_ps_bin \
  crossover_pid_lsof_has_bottle \
  crossover_wineserver_running \
  crossover_bottle_hosts_path \
  crossover_hosts_apply_block \
  crossover_hosts_block_present \
  eso_setup_print_bottle_create_steps \
  eso_setup_check_minion_mac_app \
  eso_setup_wait_for_bottle_gui \
  eso_default_mac_addons \
  crossover_bottles_root \
  crossover_bottle_dir \
  eso_mac_addons_dir \
  eso_win_addons_dir \
  eso_paths_json \
  eso_paths_json_quote \
  eso_bottle_name \
  eso_ensure_bottle_env \
  crossover_support_root \
  crossover_wine_bin \
  crossover_bottle_root_dir \
  crossover_bottle_exists \
  eso_minion_mac_app_available \
  eso_minion_mac_app_resources_dir \
  eso_steam_exe_path \
  eso_steam_exe_candidates \
  eso_steam_cx_app \
  eso_ttc_client_dir \
  eso_ttc_client_exe \
  eso_ttc_lock_path \
  eso_ttc_mac_helper_app \
  eso_ttc_client_available \
  eso_clear_ttc_lock \
  eso_status_print \
  eso_status_is_busy \
  eso_quit \
  eso_start \
  eso_stop \
  eso_awake_on \
  eso_awake_off \
  eso_launch_ttc \
  eso_launch_game \
  eso_ttc_hosts_apply \
  eso_ttc_hosts_present \
  eso_ttc_hosts_body \
  eso_ttc_probe_host_https \
  eso_ttc_errorlog_summary \
  eso_ttc_dotnet48_installed \
  eso_fix_ttc_net \
  eso_doctor \
  log_color_enabled \
  log_colors \
  log_filter_argv \
  log_info \
  log_warn \
  log_error \
  log_heading \
  log_step \
  log_prompt_yn_default_y
