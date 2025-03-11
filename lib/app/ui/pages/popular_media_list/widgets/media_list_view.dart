import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:i_iwara/utils/logger_utils.dart' show LogUtils;
import 'package:loading_more_list/loading_more_list.dart';
import 'common_media_list_widgets.dart';

// 扩展LoadingMoreBase，确保所有子类都有requestTotalCount属性和分页方法
abstract class ExtendedLoadingMoreBase<T> extends LoadingMoreBase<T> {
  int requestTotalCount = 0;
  int _pageIndex = 0;
  bool _hasMore = true;
  bool forceRefresh = false;
  
  @override
  bool get hasMore => _hasMore || forceRefresh;
  
  // 定义通用的数据获取方法，子类必须实现
  Future<Map<String, dynamic>> fetchDataFromSource(Map<String, dynamic> params, int page, int limit);
  
  // 构建查询参数，子类可以覆盖
  Map<String, dynamic> buildQueryParams(int page, int limit) {
    return <String, dynamic>{};
  }
  
  // 从API响应中提取数据列表，子类可以覆盖
  List<T> extractDataList(Map<String, dynamic> response) {
    // 默认实现，子类应该覆盖
    return [];
  }
  
  // 从API响应中提取总数量，子类可以覆盖
  int extractTotalCount(Map<String, dynamic> response) {
    // 默认实现，子类应该覆盖
    return 0;
  }
  
  // 统一实现的分页数据加载方法
  Future<List<T>> loadPageData(int pageKey, int pageSize) async {
    try {
      final params = buildQueryParams(pageKey, pageSize);
      final response = await fetchDataFromSource(params, pageKey, pageSize);
      
      requestTotalCount = extractTotalCount(response);
      return extractDataList(response);
    } catch (e) {
      // 子类可通过覆盖logError方法来自定义错误日志
      logError('加载分页数据失败', e);
      return [];
    }
  }
  
  // 统一实现的无限滚动数据加载方法
  @override
  Future<bool> loadData([bool isLoadMoreAction = false]) async {
    bool isSuccess = false;
    try {
      List<T> dataList = await loadPageData(_pageIndex, 20);
      
      if (_pageIndex == 0) {
        clear();
      }
      
      for (final T item in dataList) {
        add(item);
      }
      
      _hasMore = dataList.isNotEmpty;
      _pageIndex++;
      isSuccess = true;
    } catch (e) {
      isSuccess = false;
      logError('加载数据列表失败', e);
    }
    return isSuccess;
  }
  
  // 统一的刷新方法
  @override
  Future<bool> refresh([bool notifyStateChanged = false]) async {
    _hasMore = true;
    _pageIndex = 0;
    forceRefresh = !notifyStateChanged;
    final bool result = await super.refresh(notifyStateChanged);
    forceRefresh = false;
    return result;
  }
  
  // 统一的错误日志方法，子类可覆盖
  void logError(String message, dynamic error, [StackTrace? stackTrace]) {
    // 默认实现
    LogUtils.e('$message: $error', error: error, stack: stackTrace);
  }
}

class MediaListView<T> extends StatefulWidget {
  final LoadingMoreBase<T> sourceList;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final IconData? emptyIcon;
  final bool isPaginated;
  final ExtendedListDelegate? extendedListDelegate;
  final ScrollController? scrollController;

  const MediaListView({
    super.key,
    required this.sourceList,
    required this.itemBuilder,
    this.emptyIcon,
    this.isPaginated = false,
    this.extendedListDelegate,
    this.scrollController,
  });

  @override
  State<MediaListView<T>> createState() => _MediaListViewState<T>();
}

class _MediaListViewState<T> extends State<MediaListView<T>> {
  int currentPage = 0;
  int itemsPerPage = 20;
  bool isLoading = false;
  List<T> paginatedItems = [];
  final TextEditingController _pageController = TextEditingController();
  // 添加指示器状态
  IndicatorStatus _indicatorStatus = IndicatorStatus.fullScreenBusying;
  
  // 添加一个标志来跟踪是否是首次加载
  bool _isFirstLoad = true;
  
  // 添加一个标志来跟踪模式是否已切换
  bool _modeSwitched = false;
  
  int get totalItems {
    if (widget.sourceList is ExtendedLoadingMoreBase<T>) {
      return (widget.sourceList as ExtendedLoadingMoreBase<T>).requestTotalCount;
    }
    return 0;
  }
  
  int get totalPages => totalItems > 0 ? (totalItems / itemsPerPage).ceil() : 1;

  @override
  void initState() {
    super.initState();
    if (widget.isPaginated) {
      _loadPaginatedData(0);
    }
  }

  @override
  void didUpdateWidget(MediaListView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // 检测模式切换
    if (oldWidget.isPaginated != widget.isPaginated) {
      _modeSwitched = true;
      
      // 从瀑布流切换到分页模式
      if (widget.isPaginated && !oldWidget.isPaginated) {
        currentPage = 0;
        _loadPaginatedData(currentPage);
      }
      // 从分页切换到瀑布流模式
      else if (!widget.isPaginated && oldWidget.isPaginated) {
        // 确保瀑布流模式下数据能正确加载
        Future.microtask(() {
          if (widget.sourceList.isEmpty) {
            widget.sourceList.refresh(true);
          }
        });
      }
    }
    // 检测数据源变化
    else if (oldWidget.sourceList != widget.sourceList) {
      if (widget.isPaginated) {
        currentPage = 0;
        _loadPaginatedData(currentPage);
      } else {
        // 确保瀑布流模式下数据能正确加载
        Future.microtask(() {
          if (widget.sourceList.isEmpty) {
            widget.sourceList.refresh(true);
          }
        });
      }
    }
  }

  Future<void> _loadPaginatedData(int page) async {
    if (isLoading) return;
    
    setState(() {
      isLoading = true;
      // 根据是否是首次加载或模式切换来设置适当的指示器状态
      if (_isFirstLoad || _modeSwitched || page == 0) {
        _indicatorStatus = IndicatorStatus.fullScreenBusying;
      } else {
        _indicatorStatus = IndicatorStatus.loadingMoreBusying;
      }
    });
    
    try {
      if (widget.sourceList is ExtendedLoadingMoreBase<T>) {
        final repo = widget.sourceList as ExtendedLoadingMoreBase<T>;
        final items = await repo.loadPageData(page, itemsPerPage);
        
        // 确保组件仍然挂载
        if (!mounted) return;
        
        // 添加过渡动画效果
        if (items.isNotEmpty && paginatedItems.isNotEmpty && page != currentPage) {
          // 先设置状态为过渡中
          setState(() {
            isLoading = true;
            _indicatorStatus = IndicatorStatus.none;
          });
          
          // 短暂延迟后更新数据，制造平滑过渡效果
          await Future.delayed(const Duration(milliseconds: 150));
        }
        
        setState(() {
          paginatedItems = items;
          currentPage = page;
          isLoading = false;
          _isFirstLoad = false;
          _modeSwitched = false;
          
          // 根据结果设置适当的状态
          if (items.isEmpty && page == 0) {
            _indicatorStatus = IndicatorStatus.empty;
          } else if (items.isEmpty) {
            _indicatorStatus = IndicatorStatus.noMoreLoad;
          } else {
            _indicatorStatus = IndicatorStatus.none;
          }
        });
      } else {
        if (!mounted) return;
        
        setState(() {
          isLoading = false;
          _isFirstLoad = false;
          _modeSwitched = false;
          _indicatorStatus = IndicatorStatus.fullScreenError;
        });
      }
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        isLoading = false;
        _isFirstLoad = false;
        _modeSwitched = false;
        _indicatorStatus = page == 0 
            ? IndicatorStatus.fullScreenError 
            : IndicatorStatus.error;
      });
    }
  }

  Future<void> refresh() async {
    if (widget.isPaginated) {
      await _loadPaginatedData(0);
    } else {
      await widget.sourceList.refresh(true);
    }
  }

  // 添加错误刷新方法
  Future<void> errorRefresh() async {
    if (widget.isPaginated) {
      await _loadPaginatedData(currentPage);
    } else {
      await widget.sourceList.errorRefresh();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isPaginated) {
      return _buildPaginatedView(context);
    } else {
      return _buildInfiniteScrollView(context);
    }
  }

  Widget _buildInfiniteScrollView(BuildContext context) {
    return LoadingMoreCustomScrollView(
      controller: widget.scrollController,
      physics: const ClampingScrollPhysics(),
      slivers: <Widget>[
        LoadingMoreSliverList(
          SliverListConfig<T>(
            extendedListDelegate: widget.extendedListDelegate ??
                SliverWaterfallFlowDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: MediaQuery.of(context).size.width <= 600 ? MediaQuery.of(context).size.width / 2 : 200,
                  crossAxisSpacing: MediaQuery.of(context).size.width <= 600 ? 4 : 5,
                  mainAxisSpacing: MediaQuery.of(context).size.width <= 600 ? 4 : 5,
                ),
            itemBuilder: widget.itemBuilder,
            sourceList: widget.sourceList,
            padding: EdgeInsets.only(
              left: MediaQuery.of(context).size.width <= 600 ? 2.0 : 5.0,
              right: MediaQuery.of(context).size.width <= 600 ? 2.0 : 5.0,
              bottom: Get.context != null ? MediaQuery.of(Get.context!).padding.bottom : 0,
            ),
            lastChildLayoutType: LastChildLayoutType.foot,
            indicatorBuilder: (context, status) => buildIndicator(
              context,
              status,
              () => widget.sourceList.errorRefresh(),
              emptyIcon: widget.emptyIcon,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaginatedView(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: refresh,
            child: () {
              // 判断当前状态并显示相应的指示器
              if (_indicatorStatus == IndicatorStatus.fullScreenBusying ||
                  _indicatorStatus == IndicatorStatus.fullScreenError ||
                  (_indicatorStatus == IndicatorStatus.empty && paginatedItems.isEmpty)) {
                // 全屏状态直接显示指示器
                final indicator = buildIndicator(
                  context, 
                  _indicatorStatus, 
                  errorRefresh,
                  emptyIcon: widget.emptyIcon,
                );
                
                // 如果是SliverFillRemaining，需要套一层CustomScrollView
                if (indicator is SliverFillRemaining) {
                  return LoadingMoreCustomScrollView(
                    controller: widget.scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [indicator],
                  );
                }
                
                // 其他情况套一个SingleChildScrollView确保可滚动
                return SingleChildScrollView(
                  controller: widget.scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height - 200, // 减去大致的头部和底部高度
                    child: Center(child: indicator ?? const SizedBox.shrink()),
                  ),
                );
              }
              
              // 数据已加载，显示内容
              return LoadingMoreCustomScrollView(
                controller: widget.scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: <Widget>[
                  SliverPadding(
                    padding: EdgeInsets.only(
                      left: MediaQuery.of(context).size.width <= 600 ? 2.0 : 5.0,
                      right: MediaQuery.of(context).size.width <= 600 ? 2.0 : 5.0,
                      bottom: 60, // 为分页控制栏留出空间
                    ),
                    sliver: SliverWaterfallFlow(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => widget.itemBuilder(context, paginatedItems[index], index),
                        childCount: paginatedItems.length,
                      ),
                      gridDelegate: (widget.extendedListDelegate is SliverWaterfallFlowDelegate)
                        ? (widget.extendedListDelegate as SliverWaterfallFlowDelegate)
                        : SliverWaterfallFlowDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: MediaQuery.of(context).size.width <= 600 ? MediaQuery.of(context).size.width / 2 : 200,
                          crossAxisSpacing: MediaQuery.of(context).size.width <= 600 ? 4 : 5,
                          mainAxisSpacing: MediaQuery.of(context).size.width <= 600 ? 4 : 5,
                        ),
                    ),
                  ),
                  // 加载更多指示器
                  if (_indicatorStatus == IndicatorStatus.loadingMoreBusying ||
                      _indicatorStatus == IndicatorStatus.error ||
                      _indicatorStatus == IndicatorStatus.noMoreLoad)
                    SliverToBoxAdapter(
                      child: buildIndicator(
                        context, 
                        _indicatorStatus, 
                        errorRefresh,
                        emptyIcon: widget.emptyIcon,
                      ),
                    ),
                ],
              );
            }(),
          ),
        ),
        // 使用新的分页控制栏组件
        PaginationBar(
          currentPage: currentPage,
          totalPages: totalPages,
          totalItems: totalItems,
          isLoading: isLoading,
          onPageChanged: _loadPaginatedData,
        ),
      ],
    );
  }
} 