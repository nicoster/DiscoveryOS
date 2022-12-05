//
//  FloatingPanel.swift
//
// see https://cindori.com/developer/searchable-floating-panel
//

import SwiftUI

#if os(macOS)
/// An NSPanel subclass that implements floating panel traits.
class FloatingPanel<Content: View>: NSPanel {
	@Binding var isPresented: Bool
	
	init(view: () -> Content,
		 contentRect: NSRect,
		 backing: NSWindow.BackingStoreType = .buffered,
		 defer flag: Bool = false,
		 isPresented: Binding<Bool>) {
		/// Initialize the binding variable by assigning the whole value via an underscore
		self._isPresented = isPresented
		
		/// Init the window as usual
		super.init(contentRect: contentRect,
				   styleMask: [.nonactivatingPanel, .titled, .resizable, .closable, .fullSizeContentView],
				   backing: backing,
				   defer: flag)
		
		/// Allow the panel to be on top of other windows
		isFloatingPanel = true
		level = .floating
		
		/// Allow the pannel to be overlaid in a fullscreen space
		collectionBehavior.insert(.fullScreenAuxiliary)
		
		/// Don't show a window title, even if it's set
		titleVisibility = .hidden
		titlebarAppearsTransparent = true
		
		/// Since there is no title bar make the window moveable by dragging on the background
		isMovableByWindowBackground = true
		
		/// Hide when unfocused
		hidesOnDeactivate = true
		
		/// Hide all traffic light buttons
		standardWindowButton(.closeButton)?.isHidden = true
		standardWindowButton(.miniaturizeButton)?.isHidden = true
		standardWindowButton(.zoomButton)?.isHidden = true
		
		/// Sets animations accordingly
		animationBehavior = .utilityWindow
		
		/// Set the content view.
		/// The safe area is ignored because the title bar still interferes with the geometry
		contentView = NSHostingView(rootView: view()
			.ignoresSafeArea()
			.environment(\.floatingPanel, self))
	}
	
	/// Close automatically when out of focus, e.g. outside click
	override func resignMain() {
		super.resignMain()
		close()
	}
	
	/// Close and toggle presentation, so that it matches the current state of the panel
	override func close() {
		super.close()
		isPresented = false
	}
	
	/// `canBecomeKey` and `canBecomeMain` are both required so that text inputs inside the panel can receive focus
	override var canBecomeKey: Bool {
		return true
	}
	
	override var canBecomeMain: Bool {
		return true
	}
}

private struct FloatingPanelKey: EnvironmentKey {
	static let defaultValue: NSPanel? = nil
}

extension EnvironmentValues {
	var floatingPanel: NSPanel? {
		get { self[FloatingPanelKey.self] }
		set { self[FloatingPanelKey.self] = newValue }
	}
}

/// Add a  ``FloatingPanel`` to a view hierarchy
fileprivate struct FloatingPanelModifier<PanelContent: View>: ViewModifier {
	/// Determines wheter the panel should be presented or not
	@Binding var isPresented: Bool
	
	/// Determines the starting size of the panel
	var contentRect: CGRect = CGRect(x: 0, y: 0, width: 624, height: 512)
	
	/// Holds the panel content's view closure
	@ViewBuilder let view: () -> PanelContent
	
	/// Stores the panel instance with the same generic type as the view closure
	@State var panel: FloatingPanel<PanelContent>?
	
	func body(content: Content) -> some View {
		content
			.onAppear {
				/// When the view appears, create, center and present the panel if ordered
				panel = FloatingPanel(view: view, contentRect: contentRect, isPresented: $isPresented)
				panel?.center()
				if isPresented {
					present()
				}
			}.onDisappear {
				/// When the view disappears, close and kill the panel
				panel?.close()
				panel = nil
			}.onChange(of: isPresented) { value in
				/// On change of the presentation state, make the panel react accordingly
				if value {
					present()
				} else {
					panel?.close()
				}
			}
	}
	
	/// Present the panel and make it the key window
	func present() {
		panel?.orderFront(nil)
		panel?.makeKey()
	}
}

extension View {
	/** Present a ``FloatingPanel`` in SwiftUI fashion
	 - Parameter isPresented: A boolean binding that keeps track of the panel's presentation state
	 - Parameter contentRect: The initial content frame of the window
	 - Parameter content: The displayed content
	 **/
	func floatingPanel<Content: View>(isPresented: Binding<Bool>,
									  contentRect: CGRect = CGRect(x: 0, y: 0, width: 624, height: 400),
									  @ViewBuilder content: @escaping () -> Content) -> some View {
		self.modifier(FloatingPanelModifier(isPresented: isPresented, contentRect: contentRect, view: content))
	}
}

/// Bridge AppKit's NSVisualEffectView into SwiftUI
struct VisualEffectView: NSViewRepresentable {
	var material: NSVisualEffectView.Material
	var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
	var state: NSVisualEffectView.State = .followsWindowActiveState
	var emphasized: Bool = true
	
	func makeNSView(context: Context) -> NSVisualEffectView {
		context.coordinator.visualEffectView
	}
	
	func updateNSView(_ view: NSVisualEffectView, context: Context) {
		context.coordinator.update(
			material: material,
			blendingMode: blendingMode,
			state: state,
			emphasized: emphasized
		)
	}
	
	func makeCoordinator() -> Coordinator {
		Coordinator()
	}
	
	class Coordinator {
		let visualEffectView = NSVisualEffectView()
		
		init() {
			visualEffectView.blendingMode = .withinWindow
		}
		
		func update(material: NSVisualEffectView.Material,
					blendingMode: NSVisualEffectView.BlendingMode,
					state: NSVisualEffectView.State,
					emphasized: Bool) {
			visualEffectView.material = material
		}
	}
}

/// This SwiftUI view provides basic modular capability to a `FloatingPanel`.
public struct FloatingPanelExpandableLayout<Toolbar: View, Sidebar: View, Content: View>: View {
	@ViewBuilder let toolbar: () -> Toolbar
	@ViewBuilder let sidebar: () -> Sidebar
	@ViewBuilder let content: () -> Content
	
	/// The minimum width of the sidebar
	var sidebarWidth: CGFloat = 256.0
	/// The minimum width for both views to show
	var totalWidth: CGFloat = 512.0
	/// The minimum height
	var minHeight: CGFloat = 512.0
	
	/// Stores the expanded width of the view on toggle
	@State var expandedWidth = 512.0
	
	/// Stores a reference to the parent panel instance
	@Environment(\.floatingPanel) var panel
	
	public var body: some View {
		GeometryReader { geo in
			ZStack {
				VisualEffectView(material: .sidebar)
	 
				VStack(spacing: 0) {
					/// Display toolbar and toggle button
					HStack {
						toolbar()
						Spacer()
	 
						/// Toggle button
						Button(action: toggleExpand) {
							/// Use different SF Symbols to indicate the future state
							Image(systemName: expanded(for: geo.size.width) ?  "menubar.rectangle" : "uiwindow.split.2x1")
						}
						.buttonStyle(.plain)
							.font(.system(size: 18, weight: .light))
							.foregroundStyle(.secondary)
					}
					.padding(16)
	 
					/// Add a visual cue to separate the sections
					Divider()
	 
					/// Display sidebar and content view
					HStack(spacing: 0) {
						/// Display the sidebar and center it in a vertical stack to fill in the space
						VStack {
							Spacer()
							/// Set the minimum width to the sidebar width, and the maximum width if expanded to the sidebar width, otherwise set it to the total width
							sidebar()
								.frame(minWidth: sidebarWidth, maxWidth: expanded(for: geo.size.width) ? sidebarWidth : totalWidth)
							Spacer()
						}
	 
						/// Only show content view if expanded
						/// Set its frame so it's centered no matter what
						/// Include the divider in this, since we don't want a divider lying around if there is nothing to divide
						/// Also attach a move from edge transition
						if expanded(for: geo.size.width) {
							HStack(spacing: 0) {
								Divider()
								content()
									.frame(width: geo.size.width-sidebarWidth)
							}
							.transition(.move(edge: .trailing))
						}
					}
					.animation(.spring(), value: expanded(for: geo.size.width))
				}
			}
		}
		.frame(minWidth: sidebarWidth, minHeight: minHeight)
	}
	
	/// Toggle the expanded state of the panel
	func toggleExpand() {
		if let panel = panel {
			/// Use the parent panel's frame for reference
			let frame = panel.frame
			
			/// If expanded, store the expanded width for later use
			if expanded(for: frame.width) {
				expandedWidth = frame.width
			}
			
			/// If expanded, the new width should be the minimum sidebar width, if not, make it the largest of either the stored expanded width or the total width
			let newWidth = expanded(for: frame.width) ? sidebarWidth : max(expandedWidth, totalWidth)
			
			/// Create a new frame that centers the new width on resize
			let newFrame = CGRect(x: frame.midX-newWidth/2, y: frame.origin.y, width: newWidth, height: frame.height)
			
			/// Resize the parent panel. The view should resize itself as a consequence.
			panel.setFrame(newFrame, display: true, animate: true)
		}
	}
	
	/// Since the expanded state of the view based on its current geometry, let's make a function for it.
	func expanded(for width: CGFloat) -> Bool {
		return width >= totalWidth
	}
}

#endif
