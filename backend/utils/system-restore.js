// RL_SYSTEM_RESTORE: list backups + restore a chosen one. Snapshots current DB first.
const { exec } = require('child_process');
const fs = require('fs');
const path = require('path');
const logger = require('./logger');
const BACKUP_DIR = '/var/www/rumalink/backups';

function listBackups() {
  try {
    if (!fs.existsSync(BACKUP_DIR)) return [];
    return fs.readdirSync(BACKUP_DIR)
      .filter(n => n.endsWith('.sql'))
      .map(n => {
        const full = path.join(BACKUP_DIR, n);
        const st = fs.statSync(full);
        return { name: n, path: full, size: st.size, human: (st.size/1024).toFixed(1)+' KB', mtime: st.mtime };
      })
      .sort((a,b) => b.mtime - a.mtime);
  } catch (e) { return []; }
}

function sh(cmd) {
  return new Promise((resolve, reject) => {
    exec(cmd, { maxBuffer: 1024*1024*512 }, (err, stdout, stderr) => {
      if (err) return reject(new Error((stderr||err.message||'').slice(0,500)));
      resolve(stdout);
    });
  });
}

async function snapshotCurrent() {
  fs.mkdirSync(BACKUP_DIR, { recursive: true });
  const stamp = new Date().toISOString().replace(/[:.]/g,'-');
  const file = path.join(BACKUP_DIR, 'pre-restore-' + stamp + '.sql');
  const db = process.env.DB_NAME || 'rumalink_db';
  await sh('sudo -u postgres pg_dump ' + db + ' > "' + file + '"');
  const sz = fs.existsSync(file) ? fs.statSync(file).size : 0;
  if (sz < 1000) throw new Error('pre-restore snapshot too small — aborting');
  return { file, size: sz };
}

async function restore(fileName) {
  // resolve + validate the chosen backup is inside BACKUP_DIR (no path traversal)
  const full = path.join(BACKUP_DIR, path.basename(fileName));
  if (!fs.existsSync(full)) throw new Error('backup not found: ' + fileName);
  if (!full.startsWith(BACKUP_DIR)) throw new Error('invalid backup path');
  const sz = fs.statSync(full).size;
  if (sz < 1000) throw new Error('chosen backup looks empty — aborting');

  // 1) snapshot current state first (so this restore is itself undoable)
  const snap = await snapshotCurrent();
  logger.warn('[system-restore] snapshot of current db: ' + snap.file);

  // 2) clean slate + replay (dumps have CREATE+COPY but no DROP -> reset schema first)
  const db = process.env.DB_NAME || 'rumalink_db';
  await sh('sudo -u postgres psql -d ' + db + " -c 'DROP SCHEMA public CASCADE; CREATE SCHEMA public; GRANT ALL ON SCHEMA public TO postgres; GRANT ALL ON SCHEMA public TO public;'");
  await sh('sudo -u postgres psql -d ' + db + ' -v ON_ERROR_STOP=1 < "' + full + '"');
  logger.warn('[system-restore] restored from ' + full);
  return { ok: true, restored: full, restored_size: sz, snapshot: snap.file, snapshot_size: snap.size };
}

module.exports = { listBackups, restore };
