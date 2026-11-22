export const adminRequest = (data = {}, uid = 'admin') => ({
  auth: { uid, token: { admin: true } },
  data,
});

export function createAdminFakes(users = {}) {
  const state = {};
  const claimsSet = [];
  const accounts = {
    admin: { customClaims: { admin: true } },
    ...users,
  };
  let keyCount = 0;

  function snapshot(path) {
    const value = structuredClone(state[path] ?? null);
    return { val: () => value, exists: () => value !== null };
  }

  function set(path, value) {
    if (value === null) {
      delete state[path];
    } else {
      state[path] = structuredClone(value);
    }
    if (path === 'adminWriteLock/initialized') {
      state.adminWriteLock = { ...state.adminWriteLock, initialized: value };
    }
  }

  const database = {
    ref(path = '') {
      return {
        key: path.split('/').at(-1),
        child: (name) => database.ref(`${path}/${name}`),
        push: () => database.ref(`${path}/key-${++keyCount}`),
        async get() { return snapshot(path); },
        async set(value) { set(path, value); },
        async update(entries) {
          for (const [entry, value] of Object.entries(entries)) set(entry, value);
        },
        async transaction(change) {
          const current = snapshot(path).val();
          if (change(null) !== null) throw new Error('La caché fría debe devolver null.');
          const value = change(current);
          if (value !== undefined) set(path, value);
          return { committed: value !== undefined, snapshot: snapshot(path) };
        },
      };
    },
  };

  const auth = {
    claimsSet,
    async getUser(uid) {
      if (!accounts[uid]) throw Object.assign(new Error(), { code: 'auth/user-not-found' });
      return { uid, disabled: false, ...accounts[uid] };
    },
    async getUserByEmail(email) {
      const uid = Object.keys(accounts).find((key) => accounts[key].email === email);
      return this.getUser(uid);
    },
    async listUsers(limit, token) {
      const uids = Object.keys(accounts);
      const start = Number(token ?? 0);
      const end = start + limit;
      return {
        users: await Promise.all(uids.slice(start, end).map((uid) => this.getUser(uid))),
        pageToken: end < uids.length ? String(end) : undefined,
      };
    },
    async setCustomUserClaims(uid, claims) {
      claimsSet.push({ uid, claims });
      accounts[uid].customClaims = claims;
    },
    async updateUser(uid, data) {
      Object.assign(accounts[uid], data);
    },
  };

  return { auth, database, state, serverTimestamp: () => 123 };
}

export function auditEntries(state) {
  return Object.entries(state).filter(([path]) => path.startsWith('adminAudit/'))
    .map(([, value]) => value);
}
