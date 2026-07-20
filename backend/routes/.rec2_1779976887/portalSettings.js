const express = require('express');
const { query } = require('../config/database');
const { authenticateToken, requireISP } = require('../middleware/auth');

const router = express.Router();
router.use(authenticateToken, requireISP);

router.get('/', async (req, res, next) => {
  try {
    const result = await query('SELECT * FROM isp_captive_portal WHERE isp_id=$1', [req.user.ispId]);
    const isp = await query('SELECT company_name, logo_url, support_number FROM isps WHERE id=$1', [req.user.ispId]);
    res.json({
      portal: result.rows[0] || {
        template: 'classic', primary_color: '#00d4aa', secondary_color: '#0d1530',
        welcome_title: 'Welcome! Connect to WiFi', welcome_subtitle: 'Select a package to get started',
        show_logo: true, show_powered_by: true, enable_tv_mode: true,
        support_number: isp.rows[0]?.support_number || null,
        support_label: 'Need Help? Call Us'
      },
      isp: isp.rows[0]
    });
  } catch (err) { next(err); }
});

router.post('/', async (req, res, next) => {
  const {
    template, primary_color, secondary_color, logo_url,
    welcome_title, welcome_subtitle, bg_image_url,
    show_logo, show_powered_by, custom_css,
    support_number, support_label, enable_tv_mode
  } = req.body;

  try {
    const result = await query(`
      INSERT INTO isp_captive_portal (
        isp_id, template, primary_color, secondary_color, logo_url,
        welcome_title, welcome_subtitle, bg_image_url, show_logo, show_powered_by,
        custom_css, support_number, support_label, enable_tv_mode
      ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14)
      ON CONFLICT (isp_id) DO UPDATE SET
        template=COALESCE($2, isp_captive_portal.template),
        primary_color=COALESCE($3, isp_captive_portal.primary_color),
        secondary_color=COALESCE($4, isp_captive_portal.secondary_color),
        logo_url=COALESCE($5, isp_captive_portal.logo_url),
        welcome_title=COALESCE($6, isp_captive_portal.welcome_title),
        welcome_subtitle=COALESCE($7, isp_captive_portal.welcome_subtitle),
        bg_image_url=COALESCE($8, isp_captive_portal.bg_image_url),
        show_logo=COALESCE($9, isp_captive_portal.show_logo),
        show_powered_by=COALESCE($10, isp_captive_portal.show_powered_by),
        custom_css=COALESCE($11, isp_captive_portal.custom_css),
        support_number=COALESCE($12, isp_captive_portal.support_number),
        support_label=COALESCE($13, isp_captive_portal.support_label),
        enable_tv_mode=COALESCE($14, isp_captive_portal.enable_tv_mode),
        updated_at=NOW()
      RETURNING *
    `, [req.user.ispId, template, primary_color, secondary_color, logo_url,
        welcome_title, welcome_subtitle, bg_image_url,
        show_logo !== false, show_powered_by !== false, custom_css,
        support_number || null, support_label || 'Need Help? Call Us', enable_tv_mode !== false]);

    // Also update the isps table support_number for easy access
    if (support_number !== undefined) {
      await query('UPDATE isps SET support_number=$1 WHERE id=$2', [support_number || null, req.user.ispId]);
    }

    res.json({ portal: result.rows[0] });
  } catch (err) { next(err); }
});

module.exports = router;
