param input: OnOrderCreated
param delay: duration = 5 minutes

from {
  effect = 'scheduleJob'
  definition = 'cancelPendingOrder'
  parameters = {
    orderId = input.order.orderId
  }
  at = input.order.createdAt + delay
}