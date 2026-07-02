import 'layout_constants.dart';
import 'workbench_view_container.dart';

/// A serializable snapshot of a workbench's view-container arrangement
/// (§spec:layout-state-persistence). Bundles the four controlled-seam concerns
/// as container-keyed maps — pane [sizes], pane [order], pane [expanded], and
/// view [hidden] visibility — that a host reads once, hands to its own storage,
/// and hands back at startup. A host that persists and rehydrates this one value
/// restores a user's sidebar arrangement across restarts without deriving any
/// map shape or writing reconcile/reorder logic of its own.
///
/// The maps mirror the shell's existing seam vocabulary exactly
/// (§spec:view-stack order and expansion, §spec:view-container-title visibility,
/// §spec:resize-geometry sizing), so the state is a faithful snapshot of what
/// those seams already control, not a second model to keep in sync.
///
/// **Serialization is the host's mechanism; the shape is the shell's contract.**
/// [toJson]/[WorkbenchLayoutState.fromJson] convert to and from a JSON-encodable
/// primitive map — not bytes. The shell never encodes a string, names a storage
/// key, or writes to disk; the host owns the codec and the bytes
/// (§spec:capability-boundary). Deserialization is tolerant: it defaults absent
/// concerns and ignores unrecognized ones, so a value written by an older or
/// newer shell rehydrates without the host guarding versions.
///
/// **Reconciliation is distinct from deserialization.** [fromJson] is a dumb
/// structural round-trip. [reconcile] resolves the state against the container's
/// *current* view descriptors — which do not exist at deserialize time — dropping
/// arrangement for ids the host no longer declares, admitting newly declared
/// views at their descriptor defaults, and clamping persisted sizes to the
/// current geometry.
class WorkbenchLayoutState {
  /// Per-container pane body sizes: container id → (view id → body height in
  /// pixels), the seed-plus-commit sizing of §spec:resize-geometry.
  final Map<String, Map<String, double>> sizes;

  /// Per-container pane expansion: container id → (view id → expanded)
  /// (§spec:view-stack, §spec:section-disclosure).
  final Map<String, Map<String, bool>> expanded;

  /// Per-container pane order: container id → the full ordered view ids
  /// *including hidden panes* (§spec:view-stack). Hidden views keep their slot
  /// so re-showing restores their position (§spec:view-container-title).
  final Map<String, List<String>> order;

  /// Per-container view visibility store: container id → the set of *hidden*
  /// view ids (§spec:view-container-title, the port of VS Code's
  /// `ViewContainerModel`). Serialized as a list; [fromJson] dedupes back into a
  /// set.
  final Map<String, Set<String>> hidden;

  const WorkbenchLayoutState({
    this.sizes = const {},
    this.order = const {},
    this.expanded = const {},
    this.hidden = const {},
  });

  /// A JSON-encodable primitive map (§spec:layout-state-persistence). Sets
  /// serialize as lists so the result contains only JSON primitives; the host
  /// owns the codec (JSON, binary, a key–value store).
  Map<String, dynamic> toJson() => {
    'sizes': sizes,
    'order': order,
    'expanded': expanded,
    'hidden': {for (final e in hidden.entries) e.key: e.value.toList()},
  };

  /// Rebuild from a JSON-decoded map, tolerantly (§spec:layout-state-persistence):
  /// absent concerns default to empty, unrecognized concerns are ignored, and
  /// malformed entries are dropped rather than throwing. A value written by a
  /// different shell version rehydrates without the host guarding versions.
  factory WorkbenchLayoutState.fromJson(Map<String, dynamic> json) {
    return WorkbenchLayoutState(
      sizes: _decodeNested(json['sizes'], (v) => v is num ? v.toDouble() : null),
      order: _decodeLists(json['order']),
      expanded: _decodeNested(json['expanded'], (v) => v is bool ? v : null),
      hidden: {
        for (final e in _decodeLists(json['hidden']).entries)
          e.key: e.value.toSet(),
      },
    );
  }

  /// Decode a `{container: {viewId: value}}` map, keeping only string keys and
  /// values [parse] accepts.
  static Map<String, Map<String, T>> _decodeNested<T>(
    Object? raw,
    T? Function(Object?) parse,
  ) {
    final result = <String, Map<String, T>>{};
    if (raw is Map) {
      raw.forEach((key, inner) {
        if (key is String && inner is Map) {
          final decoded = <String, T>{};
          inner.forEach((viewId, value) {
            final parsed = parse(value);
            if (viewId is String && parsed != null) decoded[viewId] = parsed;
          });
          result[key] = decoded;
        }
      });
    }
    return result;
  }

  /// Decode a `{container: [viewId, ...]}` map, keeping only string ids.
  static Map<String, List<String>> _decodeLists(Object? raw) {
    final result = <String, List<String>>{};
    if (raw is Map) {
      raw.forEach((key, list) {
        if (key is String && list is List) {
          result[key] = [for (final e in list) if (e is String) e];
        }
      });
    }
    return result;
  }

  /// Resolve this persisted state against the container's *current* descriptors
  /// (§spec:layout-state-persistence). For each container in [live]:
  /// drops arrangement for view ids the descriptors no longer declare, admits
  /// newly declared views at their descriptor defaults, and clamps persisted
  /// sizes to each pane's geometry (`[minBody, maximumBodySize]`). Containers
  /// absent from [live] are dropped entirely. Controlled visibility views
  /// (a descriptor with `onVisibleChanged`) are excluded from [hidden] — the
  /// host owns their visibility, not the shell store.
  WorkbenchLayoutState reconcile(
    Map<String, List<WorkbenchViewDescriptor>> live,
  ) {
    const minBody = WorkbenchLayoutConstants.viewPaneMinBodyHeight;
    final newSizes = <String, Map<String, double>>{};
    final newOrder = <String, List<String>>{};
    final newExpanded = <String, Map<String, bool>>{};
    final newHidden = <String, Set<String>>{};

    live.forEach((containerId, views) {
      final byId = {for (final v in views) v.id: v};
      // A view is "known" (persisted before) if it appears in any concern, not
      // just order — a host that only toggled visibility persists a hidden set
      // with no order. A view absent from all concerns is new and takes its
      // descriptor defaults.
      final known = <String>{
        ...?order[containerId],
        ...?hidden[containerId],
        ...?expanded[containerId]?.keys,
        ...?sizes[containerId]?.keys,
      };

      // Order: persisted ids still declared, in persisted sequence, then new
      // views appended in descriptor order (mirrors WorkbenchViewContainer's
      // own reconcile in _orderedViews).
      final resolvedOrder = <String>[
        for (final id in order[containerId] ?? const <String>[])
          if (byId.containsKey(id)) id,
      ];
      for (final v in views) {
        if (!resolvedOrder.contains(v.id)) resolvedOrder.add(v.id);
      }
      newOrder[containerId] = resolvedOrder;

      // Sizes: keep entries for live views, clamped to the pane's geometry.
      final persistedSizes = sizes[containerId] ?? const <String, double>{};
      final resolvedSizes = <String, double>{};
      persistedSizes.forEach((viewId, value) {
        final view = byId[viewId];
        if (view == null) return;
        final maxBody = view.maximumBodySize ?? double.infinity;
        // A cap below the floor wins (VS Code max-over-min, §spec:view-pane-max-body).
        final floor = maxBody < minBody ? maxBody : minBody;
        resolvedSizes[viewId] = value.clamp(floor, maxBody);
      });
      if (resolvedSizes.isNotEmpty) newSizes[containerId] = resolvedSizes;

      // Expansion (uncontrolled views only): persisted value if present, else
      // the descriptor default. Controlled descriptors own their own expansion.
      final persistedExpanded =
          expanded[containerId] ?? const <String, bool>{};
      final resolvedExpanded = <String, bool>{};
      for (final v in views) {
        if (v.expanded != null) continue;
        resolvedExpanded[v.id] =
            persistedExpanded[v.id] ?? v.initiallyExpanded;
      }
      if (resolvedExpanded.isNotEmpty) {
        newExpanded[containerId] = resolvedExpanded;
      }

      // Visibility (uncontrolled views only): a view is hidden if it was hidden
      // before, or — for a newly declared view — if its descriptor starts hidden.
      final persistedHidden = hidden[containerId] ?? const <String>{};
      final resolvedHidden = <String>{};
      for (final v in views) {
        if (v.onVisibleChanged != null) continue;
        final isNew = !known.contains(v.id);
        final hide = isNew ? !v.visible : persistedHidden.contains(v.id);
        if (hide) resolvedHidden.add(v.id);
      }
      if (resolvedHidden.isNotEmpty) newHidden[containerId] = resolvedHidden;
    });

    return WorkbenchLayoutState(
      sizes: newSizes,
      order: newOrder,
      expanded: newExpanded,
      hidden: newHidden,
    );
  }

  /// Splice a reorder expressed in *visible-pane* indices back into the full
  /// [fullOrder] that still includes hidden panes (§spec:view-container-title).
  /// A header drag reports indices among the visible panes; this maps the drag
  /// from index [fromVisible] to [toVisible] onto the full order without
  /// disturbing hidden views' slots. The shell owns this rule because a host
  /// with a controlled `order` cannot translate visible indices to full-order
  /// positions without duplicating the visible-versus-hidden model.
  static List<String> applyReorder(
    List<String> fullOrder,
    Set<String> hidden,
    int fromVisible,
    int toVisible,
  ) {
    final visible = [for (final id in fullOrder) if (!hidden.contains(id)) id];
    if (fromVisible < 0 || fromVisible >= visible.length) {
      return List<String>.from(fullOrder);
    }
    final moved = visible.removeAt(fromVisible);
    visible.insert(toVisible.clamp(0, visible.length), moved);
    var vi = 0;
    return [
      for (final id in fullOrder)
        if (hidden.contains(id)) id else visible[vi++],
    ];
  }

  /// Return a copy with one container's [order], [expanded], and [sizes]
  /// replaced. Used by the layout to fold a container's reported arrangement
  /// into the aggregate snapshot.
  WorkbenchLayoutState withContainer(
    String containerId, {
    required List<String> order,
    required Map<String, bool> expanded,
    required Map<String, double> sizes,
  }) {
    return WorkbenchLayoutState(
      sizes: {...this.sizes, containerId: {...sizes}},
      order: {...this.order, containerId: [...order]},
      expanded: {...this.expanded, containerId: {...expanded}},
      hidden: hidden,
    );
  }

  /// Return a copy with one container's [hidden] view set replaced.
  WorkbenchLayoutState withHidden(String containerId, Set<String> hiddenIds) {
    return WorkbenchLayoutState(
      sizes: sizes,
      order: order,
      expanded: expanded,
      hidden: {...hidden, containerId: {...hiddenIds}},
    );
  }
}
