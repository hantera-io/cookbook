param input: OnOrderCreated
param delay: duration = 5 minutes

// Schedule a job in the future that will check if the order is still pending, and if so cancel it.
from {
  effect = 'scheduleJob'
  definition = 'cancelPendingOrder'
  parameters = {
    orderId = input.order.orderId
  }
  at = input.order.createdAt + delay
}