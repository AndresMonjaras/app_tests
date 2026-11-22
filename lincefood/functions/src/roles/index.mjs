import { defineSecret } from 'firebase-functions/params';

import { adminCallable } from '../admin/index.mjs';
import {
  createSetAdminRoleHandler,
  createSetStaffRoleHandler,
  createSetUserRoleHandler,
} from './role_handlers.mjs';

const bootstrapEmail = defineSecret('ADMIN_BOOTSTRAP_EMAIL');

export const setStaffRole = adminCallable(createSetStaffRoleHandler);
export const setUserRole = adminCallable(createSetUserRoleHandler);
export const setAdminRole = adminCallable(
  (deps) => createSetAdminRoleHandler({ ...deps, bootstrapEmail: bootstrapEmail.value() }),
  { secrets: [bootstrapEmail] },
);
