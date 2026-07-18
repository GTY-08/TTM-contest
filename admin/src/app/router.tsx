import { createBrowserRouter } from 'react-router-dom';

import { ProtectedAdminApp } from './App';
import { AuditLogsPage } from '../pages/AuditLogsPage';
import { CancelEventsPage } from '../pages/CancelEventsPage';
import { DashboardPage } from '../pages/DashboardPage';
import { ExerciseVenuesPage } from '../pages/ExerciseVenuesPage';
import { ForbiddenPage } from '../pages/ForbiddenPage';
import { LoginPage } from '../pages/LoginPage';
import { ReportDetailPage } from '../pages/ReportDetailPage';
import { ReportsPage } from '../pages/ReportsPage';
import { RestrictionsPage } from '../pages/RestrictionsPage';
import { RequestDetailPage } from '../pages/RequestDetailPage';
import { RequestsPage } from '../pages/RequestsPage';
import { SettlementsPage } from '../pages/SettlementsPage';
import { SupportInquiriesPage } from '../pages/SupportInquiriesPage';
import { UserDetailPage } from '../pages/UserDetailPage';
import { UsersPage } from '../pages/UsersPage';
import { TaskProofIncidentsPage } from '../pages/TaskProofIncidentsPage';
import { TaskProofIncidentDetailPage } from '../pages/TaskProofIncidentDetailPage';

export const router = createBrowserRouter([
  { path: '/login', element: <LoginPage /> },
  { path: '/auth/callback', element: <LoginPage /> },
  { path: '/forbidden', element: <ForbiddenPage /> },
  {
    path: '/',
    element: <ProtectedAdminApp />,
    children: [
      { index: true, element: <DashboardPage /> },
      { path: 'exercise-venues', element: <ExerciseVenuesPage /> },
      { path: 'requests', element: <RequestsPage /> },
      { path: 'requests/:id', element: <RequestDetailPage /> },
      { path: 'users', element: <UsersPage /> },
      { path: 'users/:id', element: <UserDetailPage /> },
      { path: 'restrictions', element: <RestrictionsPage /> },
      { path: 'settlements', element: <SettlementsPage /> },
      { path: 'support', element: <SupportInquiriesPage /> },
      { path: 'reports', element: <ReportsPage /> },
      { path: 'reports/:type/:id', element: <ReportDetailPage /> },
      { path: 'proof-incidents', element: <TaskProofIncidentsPage /> },
      { path: 'proof-incidents/:id', element: <TaskProofIncidentDetailPage /> },
      { path: 'cancellations', element: <CancelEventsPage /> },
      { path: 'audit', element: <AuditLogsPage /> },
    ],
  },
]);
