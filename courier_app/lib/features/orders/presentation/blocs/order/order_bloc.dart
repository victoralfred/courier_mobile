import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:delivery_app/features/orders/domain/repositories/order_repository.dart';
import 'package:delivery_app/features/orders/presentation/blocs/order/order_event.dart';
import 'package:delivery_app/features/orders/presentation/blocs/order/order_state.dart';

class OrderBloc extends Bloc<OrderEvent, OrderState> {
  final OrderRepository orderRepository;
  StreamSubscription? _orderSubscription;
  StreamSubscription? _ordersSubscription;

  OrderBloc({required this.orderRepository}) : super(OrderInitial()) {
    on<LoadUserOrders>(_onLoadUserOrders);
    on<LoadActiveOrders>(_onLoadActiveOrders);
    on<LoadCompletedOrders>(_onLoadCompletedOrders);
    on<LoadOrderById>(_onLoadOrderById);
    on<CreateOrder>(_onCreateOrder);
    on<UpdateOrderStatus>(_onUpdateOrderStatus);
    on<AssignDriver>(_onAssignDriver);
    on<CancelOrder>(_onCancelOrder);
    on<WatchOrder>(_onWatchOrder);
    on<WatchActiveOrders>(_onWatchActiveOrders);
    on<WatchedOrderUpdated>(_onOrderUpdated);
    on<OrdersListUpdated>(_onOrdersListUpdated);
  }

  Future<void> _onLoadUserOrders(
    LoadUserOrders event,
    Emitter<OrderState> emit,
  ) async {
    emit(OrderLoading());

    final result = await orderRepository.getOrdersByUserId(event.userId);

    result.fold(
      (failure) => emit(OrderError(failure.message)),
      (orders) => emit(OrdersLoaded(orders)),
    );
  }

  Future<void> _onLoadActiveOrders(
    LoadActiveOrders event,
    Emitter<OrderState> emit,
  ) async {
    emit(OrderLoading());

    final result = await orderRepository.getActiveOrders(event.userId);

    result.fold(
      (failure) => emit(OrderError(failure.message)),
      (orders) => emit(OrdersLoaded(orders)),
    );
  }

  Future<void> _onLoadCompletedOrders(
    LoadCompletedOrders event,
    Emitter<OrderState> emit,
  ) async {
    emit(OrderLoading());

    final result = await orderRepository.getCompletedOrders(event.userId);

    result.fold(
      (failure) => emit(OrderError(failure.message)),
      (orders) => emit(OrdersLoaded(orders)),
    );
  }

  Future<void> _onLoadOrderById(
    LoadOrderById event,
    Emitter<OrderState> emit,
  ) async {
    emit(OrderLoading());

    final result = await orderRepository.getOrderById(event.orderId);

    result.fold(
      (failure) => emit(OrderError(failure.message)),
      (order) => emit(OrderLoaded(order)),
    );
  }

  Future<void> _onCreateOrder(
    CreateOrder event,
    Emitter<OrderState> emit,
  ) async {
    emit(OrderLoading());

    final result = await orderRepository.createOrder(event.order);

    result.fold(
      (failure) => emit(OrderError(failure.message)),
      (order) => emit(OrderCreated(order)),
    );
  }

  Future<void> _onUpdateOrderStatus(
    UpdateOrderStatus event,
    Emitter<OrderState> emit,
  ) async {
    emit(OrderLoading());

    final result = await orderRepository.updateOrderStatus(
      orderId: event.orderId,
      status: event.status,
      pickupStartedAt: event.pickupStartedAt,
      pickupCompletedAt: event.pickupCompletedAt,
      completedAt: event.completedAt,
      cancelledAt: event.cancelledAt,
    );

    result.fold(
      (failure) => emit(OrderError(failure.message)),
      (order) => emit(OrderUpdated(order)),
    );
  }

  Future<void> _onAssignDriver(
    AssignDriver event,
    Emitter<OrderState> emit,
  ) async {
    emit(OrderLoading());

    final result = await orderRepository.assignOrderToDriver(
      orderId: event.orderId,
      driverId: event.driverId,
    );

    result.fold(
      (failure) => emit(OrderError(failure.message)),
      (order) => emit(OrderUpdated(order)),
    );
  }

  Future<void> _onCancelOrder(
    CancelOrder event,
    Emitter<OrderState> emit,
  ) async {
    emit(OrderLoading());

    final result = await orderRepository.deleteOrder(event.orderId);

    result.fold(
      (failure) => emit(OrderError(failure.message)),
      (_) => emit(OrderCancelled(event.orderId)),
    );
  }

  Future<void> _onWatchOrder(
    WatchOrder event,
    Emitter<OrderState> emit,
  ) async {
    // Cancel previous subscription
    await _orderSubscription?.cancel();

    // Start watching the order
    _orderSubscription = orderRepository.watchOrderById(event.orderId).listen(
      (order) {
        add(WatchedOrderUpdated(order));
      },
    );
  }

  Future<void> _onWatchActiveOrders(
    WatchActiveOrders event,
    Emitter<OrderState> emit,
  ) async {
    // Cancel previous subscription
    await _ordersSubscription?.cancel();

    // Start watching active orders
    _ordersSubscription =
        orderRepository.watchActiveOrders(event.userId).listen(
      (orders) {
        add(OrdersListUpdated(orders));
      },
    );
  }

  void _onOrderUpdated(
    WatchedOrderUpdated event,
    Emitter<OrderState> emit,
  ) {
    emit(OrderWatching(event.order));
  }

  void _onOrdersListUpdated(
    OrdersListUpdated event,
    Emitter<OrderState> emit,
  ) {
    emit(OrdersWatching(event.orders));
  }

  @override
  Future<void> close() {
    _orderSubscription?.cancel();
    _ordersSubscription?.cancel();
    return super.close();
  }
}
