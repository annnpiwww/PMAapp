// Shared branch routing functions for Edge Functions (SEC-05)
// Mirrors BranchService.parseBranchFromName + DailyTaskService.tasksTable

export function resolveTasksTableForCabang(cabang: string): string {
  const lower = cabang.trim().toLowerCase();
  if (
    lower === 'ho' ||
    lower === 'hom' ||
    lower.includes('ho makassar') ||
    lower.includes('head office') ||
    lower.includes('makassar')
  ) {
    return 'daily_tasks_ho';
  }
  if (lower.includes('bali') || lower.includes('dps')) {
    return 'daily_tasks_bali';
  }
  return 'daily_tasks_manado';
}
