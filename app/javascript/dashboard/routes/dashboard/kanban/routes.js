/* eslint arrow-body-style: 0 */
import { frontendURL } from '../../../helper/URLHelper';
const KanbanView = () => import('./components/KanbanView.vue');

export const routes = [
  {
    path: frontendURL('accounts/:accountId/kanban'),
    name: 'kanban_dashboard',
    meta: {
      permissions: ['administrator', 'agent', 'contact_manage'],
    },
    component: KanbanView,
  },
];
