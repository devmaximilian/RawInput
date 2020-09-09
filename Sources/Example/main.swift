//
//  File.swift
//  
//
//  Created by Maximilian Wendel on 2020-09-09.
//

import Foundation
import RawInput

RawInput.observe { value in
    print(value)
}

RunLoop.main.run()
