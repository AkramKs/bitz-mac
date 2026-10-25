import Foundation
#if canImport(Darwin)
@preconcurrency import Darwin

package enum MachCompatibility {
    @inline(__always)
    package static func deallocateHostPort(_ hostPort: mach_port_t) {
        mach_port_deallocate(mach_task_self_, hostPort)
    }
}
#endif
