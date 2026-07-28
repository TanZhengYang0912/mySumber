const adminTabletBreakpoint = 840.0;

bool usesAdminTabletLayout(double viewportWidth) =>
    viewportWidth >= adminTabletBreakpoint;
