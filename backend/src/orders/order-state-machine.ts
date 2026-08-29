import { ApiError } from '../common/errors/api-error';
import { ErrorCodes } from '../common/errors/error-codes';
import {
  TRANSITION_RULES,
  TransitionActor,
  isOrderStatus,
  isTerminal,
  OrderStatus,
} from './order-status';

export type TransitionRequest = {
  from: OrderStatus;
  to: string;
  actor: TransitionActor;
};

export class OrderStateMachine {
  assert(request: TransitionRequest): OrderStatus {
    if (!isOrderStatus(request.to)) {
      throw new ApiError(
        ErrorCodes.INVALID_TRANSITION,
        'Unknown order status',
        400,
      );
    }
    const to = request.to;
    if (request.from === to) {
      throw new ApiError(
        ErrorCodes.INVALID_TRANSITION,
        `Order is already ${to}`,
        409,
      );
    }
    if (isTerminal(request.from)) {
      throw new ApiError(
        ErrorCodes.INVALID_TRANSITION,
        `Order is ${request.from} and cannot change`,
        409,
      );
    }

    if (to === 'CANCELLED' && request.actor === 'ADMIN' && !isTerminal(request.from)) {
      return to;
    }

    const rule = TRANSITION_RULES.find(
      (candidate) =>
        candidate.from === request.from && candidate.to === to,
    );
    if (!rule) {
      throw new ApiError(
        ErrorCodes.INVALID_TRANSITION,
        `Transition ${request.from} → ${to} is not allowed`,
        409,
      );
    }
    if (!rule.actors.includes(request.actor)) {
      throw new ApiError(
        ErrorCodes.FORBIDDEN,
        `Actor ${request.actor} cannot apply ${request.from} → ${to}`,
        403,
      );
    }
    return to;
  }
}
