def add_user_to_license_for_domain(user: User, to_date: date, licence: License) -> [UserLicense, bool]:
    """
    Creates a user license object with using a user, license and to_date.
    Returns true or false based on its success.
    """
    product_plan = ProductPlan.objects.get(id=licence.product_plan_id)
    access_type = AccessType.objects.get(id=product_plan.access_type_id)
    if access_type.label.lower() == "newsletter":
        return None
    # Check to see if the license is valid
    existing_user_licence = user.user_licenses.get_active().filter(license=licence).first()
    if existing_user_licence:
        return existing_user_licence, False
    if to_date is not None and to_date <= licence.to_date:
        expiry_datetime = date_to_max_datetime(to_date)
        active_status = LicenseStatus.objects.get(slug=LicenseStatus.ACTIVE_SLUG)
        # Create user license object
        user_license, created = UserLicense.objects.get_or_create(user=user, license=licence,
                                                                  expiry_datetime=expiry_datetime,
                                                                  license_status=active_status)
        return user_license, created
    # Return error if the license isn't valid.
    # Code is none as it then calls the default code of 400.
    raise ParseError(detail={"details_text": "The expiry date is either incorrect", "type": "warning"},
                     code=None)