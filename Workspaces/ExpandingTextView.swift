//
//  ExpandingTextViw.swift
//  Workspaces
//
//  Created by Joannis Orlandos on 19/04/2021.
//

import SwiftUI

/// A control that displays an editable text interface.
public struct ExpandingTextView<Label: View>: View {
    private let label: Label
    let heightRange: Range<CGFloat>
    @Binding var isDisabled: Bool
    
    @Binding private var text: String
    @State var height: CGFloat
    
    private var onEditingChanged: (Bool) -> Void
    private var onCommit: () -> Void
    
    public var body: some View {
        return ZStack(alignment: Alignment(horizontal: .leading, vertical: .top)) {
            label
                .visible(text.isEmpty)
                .animation(.none)
            
            _ExpandingTextView(
                text: $text,
                height: $height,
                heightRange: heightRange,
                isDisabled: $isDisabled,
                onEditingChanged: onEditingChanged,
                onCommit: onCommit
            )
        }.frame(height: height)
    }
}

// MARK: - API -

extension ExpandingTextView where Label == EmptyView {
    public init(
        text: Binding<String>,
        heightRange: Range<CGFloat>,
        isDisabled: Binding<Bool>,
        onEditingChanged: @escaping (Bool) -> Void = { _ in },
        onCommit: @escaping () -> Void = { }
    ) {
        self.label = EmptyView()
        self._text = text
        self.onEditingChanged = onEditingChanged
        self.onCommit = onCommit
        self.heightRange = heightRange
        self._height = State(initialValue: heightRange.lowerBound)
        self._isDisabled = isDisabled
    }
    
    public init(
        text: Binding<String?>,
        heightRange: Range<CGFloat>,
        isDisabled: Binding<Bool>,
        onEditingChanged: @escaping (Bool) -> Void = { _ in },
        onCommit: @escaping () -> Void = { }
    ) {
        self.init(
            text: text.withDefaultValue(String()),
            heightRange: heightRange,
            isDisabled: isDisabled,
            onEditingChanged: onEditingChanged,
            onCommit: onCommit
        )
    }
}

extension ExpandingTextView where Label == Text {
    public init<S: StringProtocol>(
        _ title: S,
        text: Binding<String>,
        heightRange: Range<CGFloat>,
        isDisabled: Binding<Bool>,
        onEditingChanged: @escaping (Bool) -> Void = { _ in },
        onCommit: @escaping () -> Void = { }
    ) {
        self.label = Text(title).foregroundColor(.placeholderText)
        self._text = text
        self.heightRange = heightRange
        self.onEditingChanged = onEditingChanged
        self.onCommit = onCommit
        self._height = State(initialValue: heightRange.lowerBound)
        self._isDisabled = isDisabled
    }
    
    public init<S: StringProtocol>(
        _ title: S,
        text: Binding<String?>,
        heightRange: Range<CGFloat>,
        isDisabled: Binding<Bool>,
        onEditingChanged: @escaping (Bool) -> Void = { _ in },
        onCommit: @escaping () -> Void = { }
    ) {
        self.init(
            title,
            text: text.withDefaultValue(String()),
            heightRange: heightRange,
            isDisabled: isDisabled,
            onEditingChanged: onEditingChanged,
            onCommit: onCommit
        )
    }
}

// MARK: - Implementation -

fileprivate struct _ExpandingTextView: UIViewRepresentable {
    typealias UIViewType = _UITextView
    
    @Binding private var text: String
    let heightRange: Range<CGFloat>
    @Binding var height: CGFloat
    @Binding var isDisabled: Bool
    
    private var onEditingChanged: (Bool) -> Void
    private var onCommit: () -> Void
    
    init(
        text: Binding<String>,
        height: Binding<CGFloat>,
        heightRange: Range<CGFloat>,
        isDisabled: Binding<Bool>,
        onEditingChanged: @escaping (Bool) -> Void = { _ in },
        onCommit: @escaping () -> Void = { }
    ) {
        self._text = text
        self._height = height
        self.heightRange = heightRange
        self._isDisabled = isDisabled
        self.onEditingChanged = onEditingChanged
        self.onCommit = onCommit
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var view: _ExpandingTextView
        
        init(_ view: _ExpandingTextView) {
            self.view = view
        }
        
        func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
            !view.isDisabled
        }
        
        func textViewDidBeginEditing(_ textView: UITextView) {
            DispatchQueue.main.async { [weak self] in
                self?.view.onEditingChanged(true)
            }
        }
        
        func textViewDidChange(_ textView: UITextView) {
            DispatchQueue.main.async { [weak self] in
                self?.view.text = textView.text
                self?.view.recalculateHeight(textView: textView)
            }
        }
        
        func textViewDidEndEditing(_ textView: UITextView) {
            DispatchQueue.main.async { [weak self] in
                self?.view.onEditingChanged(false)
                self?.view.onCommit()
            }
        }
    }
    
    func makeUIView(context: Self.Context) -> _UITextView {
        let result = _UITextView()
        result.delegate = context.coordinator
        
        updateUIView(result, context: context)
        
        return result
    }
    
    func recalculateHeight(textView: UITextView) {
        let fixedWidth = textView.frame.size.width
        let size = textView.sizeThatFits(CGSize(width: fixedWidth, height: .infinity))
        let height = max(min(size.height, self.heightRange.upperBound), self.heightRange.lowerBound)
        
        // If the sizes are almost identical the view will not entirely rerender. Saving a tonne of performance.
        // This also takes care of any mis-measurements with Double rounding errors
        if abs(self.height - height) >= 1 {
            textView.frame.size.height = height
            DispatchQueue.main.async {
                self.height = height
            }
        }
    }
    
    func updateUIView(_ uiView: _UITextView, context: Self.Context) {
        var cursorOffset: Int?
        
        // Record the current cursor offset.
        if let selectedRange = uiView.selectedTextRange {
            cursorOffset = uiView.offset(from: uiView.beginningOfDocument, to: selectedRange.start)
        }
        
        uiView.backgroundColor = nil
        uiView.font = .systemFont(ofSize: 16)
        
        // `UITextView`'s default font is smaller than SwiftUI's default font.
        // `.preferredFont(forTextStyle: .body)` is used when `context.environment.font` is nil.
        uiView.font = context.environment.font?.toUIFont() ?? .preferredFont(forTextStyle: .body)
        #if !os(tvOS)
        uiView.isEditable = context.environment.isEnabled
        #endif
        uiView.isScrollEnabled = context.environment.isScrollEnabled
        uiView.isSelectable = !isDisabled
        uiView.isEditable = !isDisabled
        uiView.text = text
        uiView.textContainerInset = .zero
        recalculateHeight(textView: uiView)
        
        // Reset the cursor offset if possible.
        if let cursorOffset = cursorOffset, let position = uiView.position(from: uiView.beginningOfDocument, offset: cursorOffset), let textRange = uiView.textRange(from: position, to: position) {
            uiView.selectedTextRange = textRange
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
}

class _UITextView: UITextView {
    public override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        return false
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        textContainerInset = .zero
        textContainer.lineFragmentPadding = 0
    }
}

