//
//  customOverlayView.swift
//  SwiftyOnboard
//
//  Created by Jay on 3/26/17.
//  Copyright © 2017 Juan Pablo Fernandez. All rights reserved.
//

import UIKit

open class SwiftyOnboardOverlay: UIView {
    
    open var pageControl: UIPageControl = {
        let pageControl = UIPageControl()
        pageControl.translatesAutoresizingMaskIntoConstraints = false
        pageControl.currentPage = 0
        pageControl.pageIndicatorTintColor = UIColor.lightGray
        return pageControl
    }()
    
    open var continueButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "arrow.right"), for: .normal)
        button.tintColor = .white
        button.backgroundColor = UIColor(red: 0.882, green: 0.192, blue: 0.357, alpha: 1)
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 14, bottom: 0, right: 14)
        button.layer.cornerRadius = 12
        return button
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override open func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        for subview in subviews {
            if !subview.isHidden && subview.alpha > 0 && subview.isUserInteractionEnabled && subview.point(inside: convert(point, to: subview), with: event) {
                return true
            }
        }
        return false
    }
    
    open func set(style: SwiftyOnboardStyle) {
        switch style {
        case .light:
            continueButton.setTitleColor(.label, for: .normal)
            pageControl.currentPageIndicatorTintColor = UIColor.label
        case .dark:
            continueButton.setTitleColor(.label, for: .normal)
            pageControl.currentPageIndicatorTintColor = UIColor.label
        }
    }
    
    open func page(count: Int) {
        pageControl.numberOfPages = count
    }
    
    open func currentPage(index: Int) {
        pageControl.currentPage = index
    }
    
    func setUp() {
        self.addSubview(pageControl)
        
        let margin = self.layoutMarginsGuide
        pageControl.heightAnchor.constraint(equalToConstant: 15).isActive = true
        pageControl.bottomAnchor.constraint(equalTo: margin.bottomAnchor, constant: -10).isActive = true
        pageControl.leadingAnchor.constraint(equalTo: margin.leadingAnchor, constant: 10).isActive = true
        pageControl.trailingAnchor.constraint(equalTo: margin.trailingAnchor, constant: -10).isActive = true
        
        self.addSubview(continueButton)
        continueButton.heightAnchor.constraint(equalToConstant: 34).isActive = true
        continueButton.bottomAnchor.constraint(equalTo: margin.bottomAnchor).isActive = true
        continueButton.trailingAnchor.constraint(equalTo: margin.trailingAnchor, constant: -20).isActive = true
    }
    
}
