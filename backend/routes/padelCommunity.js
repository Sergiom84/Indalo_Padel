import express from 'express';
import { authenticateToken } from '../middleware/auth.js';
import { validate } from '../middleware/validate.js';
import {
  createCommunityPlanSchema,
  previewCommunityConflictsSchema,
  proposeCommunityTimeSchema,
  respondCommunityPlanSchema,
  submitMatchResultSchema,
  updateCommunityPlanSchema,
  updateCommunityReservationSchema,
} from '../validators/communityValidators.js';
import {
  cancelCommunityPlan,
  createCommunityPlan,
  getCommunityDashboard,
  getCommunityDashboardBootstrap,
  getMatchResult,
  markCommunityNotificationRead,
  previewCommunityPlanConflicts,
  proposeCommunityPlanTime,
  respondToCommunityPlan,
  submitMatchResult,
  updateCommunityPlan,
  updateCommunityReservationStatus,
} from '../services/padelCommunityService.js';

const router = express.Router();

router.get('/', authenticateToken, async (req, res) => {
  try {
    const dashboard = await getCommunityDashboard(req.user.userId);
    res.json(dashboard);
  } catch (error) {
    console.error('Error obteniendo comunidad:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

router.get('/bootstrap', authenticateToken, async (req, res) => {
  try {
    const bootstrap = await getCommunityDashboardBootstrap(req.user.userId);
    res.json(bootstrap);
  } catch (error) {
    console.error('Error obteniendo bootstrap de comunidad:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

router.post(
  '/conflicts/preview',
  authenticateToken,
  validate(previewCommunityConflictsSchema),
  async (req, res) => {
    try {
      const result = await previewCommunityPlanConflicts({
        planId: req.body.plan_id ?? null,
        userId: req.user.userId,
        scheduledDate: req.body.scheduled_date,
        scheduledTime: req.body.scheduled_time,
        participantUserIds: req.body.participant_user_ids,
        modality: req.body.modality ?? 'amistoso',
        capacity: req.body.capacity ?? null,
      });
      res.status(result.status).json(result.body);
    } catch (error) {
      console.error('Error previsualizando conflictos de comunidad:', error);
      res.status(500).json({ error: 'Error interno del servidor' });
    }
  },
);

router.post(
  '/',
  authenticateToken,
  validate(createCommunityPlanSchema),
  async (req, res) => {
    try {
      const result = await createCommunityPlan({
        userId: req.user.userId,
        scheduledDate: req.body.scheduled_date,
        scheduledTime: req.body.scheduled_time,
        participantUserIds: req.body.participant_user_ids,
        modality: req.body.modality ?? null,
        capacity: req.body.capacity ?? null,
        venueId: req.body.club_id ?? req.body.venue_id ?? null,
        postPadelPlan: req.body.post_padel_plan ?? null,
        notes: req.body.notes ?? null,
        forceSend: req.body.force_send ?? false,
      });
      res.status(result.status).json(result.body);
    } catch (error) {
      console.error('Error creando convocatoria:', error);
      res.status(500).json({ error: 'Error interno del servidor' });
    }
  },
);

router.put(
  '/:id',
  authenticateToken,
  validate(updateCommunityPlanSchema),
  async (req, res) => {
    try {
      const result = await updateCommunityPlan({
        planId: Number.parseInt(req.params.id, 10),
        userId: req.user.userId,
        scheduledDate: req.body.scheduled_date,
        scheduledTime: req.body.scheduled_time,
        participantUserIds: req.body.participant_user_ids,
        modality: req.body.modality ?? 'amistoso',
        capacity: req.body.capacity ?? null,
        venueId: req.body.club_id ?? req.body.venue_id ?? null,
        postPadelPlan: req.body.post_padel_plan ?? null,
        notes: req.body.notes ?? null,
        expectedUpdatedAt: req.body.updated_at ?? null,
        forceSend: req.body.force_send ?? false,
      });
      res.status(result.status).json(result.body);
    } catch (error) {
      console.error('Error actualizando convocatoria:', error);
      res.status(500).json({ error: 'Error interno del servidor' });
    }
  },
);

router.post(
  '/:id/respond',
  authenticateToken,
  validate(respondCommunityPlanSchema),
  async (req, res) => {
    try {
      const result = await respondToCommunityPlan({
        planId: Number.parseInt(req.params.id, 10),
        userId: req.user.userId,
        action: req.body.action,
        expectedUpdatedAt: req.body.updated_at ?? null,
      });
      res.status(result.status).json(result.body);
    } catch (error) {
      console.error('Error respondiendo convocatoria:', error);
      res.status(500).json({ error: 'Error interno del servidor' });
    }
  },
);

router.post(
  '/:id/propose-time',
  authenticateToken,
  validate(proposeCommunityTimeSchema),
  async (req, res) => {
    try {
      const result = await proposeCommunityPlanTime({
        planId: Number.parseInt(req.params.id, 10),
        userId: req.user.userId,
        scheduledDate: req.body.scheduled_date,
        scheduledTime: req.body.scheduled_time,
        expectedUpdatedAt: req.body.updated_at ?? null,
      });
      res.status(result.status).json(result.body);
    } catch (error) {
      console.error('Error proponiendo horario:', error);
      res.status(500).json({ error: 'Error interno del servidor' });
    }
  },
);

router.post(
  '/:id/reservation-status',
  authenticateToken,
  validate(updateCommunityReservationSchema),
  async (req, res) => {
    try {
      const result = await updateCommunityReservationStatus({
        planId: Number.parseInt(req.params.id, 10),
        userId: req.user.userId,
        status: req.body.status,
        handledByUserId: req.body.handled_by_user_id ?? null,
        expectedUpdatedAt: req.body.updated_at ?? null,
      });
      res.status(result.status).json(result.body);
    } catch (error) {
      console.error('Error actualizando estado de reserva:', error);
      res.status(500).json({ error: 'Error interno del servidor' });
    }
  },
);

router.delete('/:id', authenticateToken, async (req, res) => {
  try {
    const result = await cancelCommunityPlan({
      planId: Number.parseInt(req.params.id, 10),
      userId: req.user.userId,
      expectedUpdatedAt: req.body?.updated_at ?? null,
    });
    res.status(result.status).json(result.body);
  } catch (error) {
    console.error('Error cancelando convocatoria:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

router.get('/:id/result', authenticateToken, async (req, res) => {
  try {
    const result = await getMatchResult({
      planId: Number.parseInt(req.params.id, 10),
      userId: req.user.userId,
    });
    res.status(result.status).json(result.body);
  } catch (error) {
    console.error('Error obteniendo resultado de partido:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

router.post(
  '/:id/result/submit',
  authenticateToken,
  validate(submitMatchResultSchema),
  async (req, res) => {
    try {
      const result = await submitMatchResult({
        planId: Number.parseInt(req.params.id, 10),
        userId: req.user.userId,
        partnerUserId: req.body.partner_user_id ?? null,
        winnerTeam: req.body.winner_team,
        sets: req.body.sets,
      });
      res.status(result.status).json(result.body);
    } catch (error) {
      console.error('Error registrando resultado de partido:', error);
      res.status(500).json({ error: 'Error interno del servidor' });
    }
  },
);

router.post('/notifications/:id/read', authenticateToken, async (req, res) => {
  try {
    const result = await markCommunityNotificationRead({
      notificationId: Number.parseInt(req.params.id, 10),
      userId: req.user.userId,
    });
    res.status(result.status).json(result.body);
  } catch (error) {
    console.error('Error marcando aviso de comunidad como leído:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

export default router;
