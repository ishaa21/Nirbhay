/**
 * Validator for Emergency Contacts request payloads
 */

const validateCreateContact = (data) => {
  const errors = [];
  const name = data.name || data.contactName;
  const phone = data.phone || data.phoneNumber;
  const relationship = data.relationship;
  const autoAlert = data.autoAlert !== undefined ? data.autoAlert : data.auto_alert;

  if (!name || typeof name !== 'string' || name.trim().length === 0) {
    errors.push('Contact name is required and cannot be empty.');
  } else if (name.trim().length > 255) {
    errors.push('Contact name cannot exceed 255 characters.');
  }

  if (!phone || typeof phone !== 'string' || phone.trim().length === 0) {
    errors.push('Phone number is required and cannot be empty.');
  } else {
    const phoneRegex = /^[+0-9\s\-()]{7,20}$/;
    if (!phoneRegex.test(phone.trim())) {
      errors.push('Invalid phone number format. Please provide a valid phone number (7-20 digits).');
    }
  }

  if (relationship && (typeof relationship !== 'string' || relationship.trim().length > 100)) {
    errors.push('Relationship must be a text string of max 100 characters.');
  }

  if (autoAlert !== undefined && typeof autoAlert !== 'boolean') {
    errors.push('Alert preference (autoAlert) must be a boolean value (true or false).');
  }

  return {
    isValid: errors.length === 0,
    errors,
    sanitized: {
      name: name ? name.trim() : '',
      phone: phone ? phone.trim() : '',
      relationship: relationship ? relationship.trim() : '',
      autoAlert: autoAlert !== undefined ? Boolean(autoAlert) : true,
    },
  };
};

const validateUpdateContact = (data) => {
  const errors = [];
  const name = data.name !== undefined ? data.name : data.contactName;
  const phone = data.phone !== undefined ? data.phone : data.phoneNumber;
  const relationship = data.relationship;
  const autoAlert = data.autoAlert !== undefined ? data.autoAlert : data.auto_alert;

  if (name !== undefined) {
    if (typeof name !== 'string' || name.trim().length === 0) {
      errors.push('Contact name cannot be empty.');
    } else if (name.trim().length > 255) {
      errors.push('Contact name cannot exceed 255 characters.');
    }
  }

  if (phone !== undefined) {
    if (typeof phone !== 'string' || phone.trim().length === 0) {
      errors.push('Phone number cannot be empty.');
    } else {
      const phoneRegex = /^[+0-9\s\-()]{7,20}$/;
      if (!phoneRegex.test(phone.trim())) {
        errors.push('Invalid phone number format. Please provide a valid phone number (7-20 digits).');
      }
    }
  }

  if (relationship !== undefined && relationship !== null && (typeof relationship !== 'string' || relationship.trim().length > 100)) {
    errors.push('Relationship must be a text string of max 100 characters.');
  }

  if (autoAlert !== undefined && typeof autoAlert !== 'boolean') {
    errors.push('Alert preference (autoAlert) must be a boolean value (true or false).');
  }

  return {
    isValid: errors.length === 0,
    errors,
    sanitized: {
      name: name !== undefined ? name.trim() : undefined,
      phone: phone !== undefined ? phone.trim() : undefined,
      relationship: relationship !== undefined ? (relationship ? relationship.trim() : '') : undefined,
      autoAlert: autoAlert !== undefined ? Boolean(autoAlert) : undefined,
    },
  };
};

module.exports = {
  validateCreateContact,
  validateUpdateContact,
};
