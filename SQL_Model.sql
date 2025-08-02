-- ============================================================
-- Agent Ranking Model: Real-Time Matching Logic for Astra
-- Author: Michael Walker
-- Last Updated: August 2025
--
-- Overview:
-- This SQL model ranks space travel agents based on a mix of overall performance,
-- customer ratings, revenue impact, and contextual familiarity with a prospective customer.
--
-- The goal is to recommend the *best-fit agent* for a new customer inquiry,
-- based on available booking history and agent track records.
--
-- Key Features:
--  - Includes customer-specific context (Communication Method, Lead Source,
--    Destination, and Launch Location) as scoring inputs.
--  - Agents are scored on a weighted basis, incorporating:
--      • Customer Service Rating (30%)
--      • Booking Conversion Rate (25%)
--      • Average Revenue per Confirmed Booking (25%)
--      • Years of Service (10%)
--      • Familiarity with context inputs (5% each)
--  - Automatically prioritizes returning customers by assigning them back to
--    their previous agent *if* the last booking was successful.
--
-- Expected Input Tables:
--  - space_travel_agents
--  - assignment_history
--  - bookings
--
-- Output:
--  - A ranked list of agents (descending by score) for use in assignment.
--
-- To Use:
--  - Replace the values inside the query (CustomerName, CommunicationMethod, etc.)
--    before running, or wrap as a stored procedure for automation.
-- ============================================================


-- Step 1: Create agent performance summary
DROP VIEW IF EXISTS agent_summary;
CREATE VIEW agent_summary AS
SELECT
    st.AgentID,
    st.FirstName,
    st.LastName,
    st.AverageCustomerServiceRating,
    st.YearsOfService,
    COUNT(ah.AssignmentID) AS TotalAssignments,
    COALESCE(SUM(CASE WHEN b.BookingStatus = 'Confirmed' THEN 1 ELSE 0 END), 0) AS ConfirmedBookings,
    COALESCE(SUM(CASE WHEN b.BookingStatus = 'Cancelled' THEN 1 ELSE 0 END), 0) AS CancelledBookings,
    COALESCE(SUM(CASE WHEN b.BookingStatus = 'Pending' THEN 1 ELSE 0 END), 0) AS PendingBookings,

    -- Conversion rate = confirmed bookings / total assignments
    CASE
        WHEN COUNT(ah.AssignmentID) > 0 THEN
            SUM(CASE WHEN b.BookingStatus = 'Confirmed' THEN 1 ELSE 0 END) * 1.0 / COUNT(ah.AssignmentID)
        ELSE 0
    END AS ConversionRate,

    -- Average revenue per confirmed booking
    CASE
        WHEN SUM(CASE WHEN b.BookingStatus = 'Confirmed' THEN 1 ELSE 0 END) > 0 THEN
            SUM(CASE WHEN b.BookingStatus = 'Confirmed' THEN b.TotalRevenue ELSE 0 END) * 1.0 /
            SUM(CASE WHEN b.BookingStatus = 'Confirmed' THEN 1 ELSE 0 END)
        ELSE 0
    END AS AvgRevenuePerBooking

FROM space_travel_agents AS st
LEFT JOIN assignment_history AS ah ON ah.AgentID = st.AgentID
LEFT JOIN bookings AS b ON b.AssignmentID = ah.AssignmentID
GROUP BY
    st.AgentID, st.FirstName, st.LastName,
    st.AverageCustomerServiceRating, st.YearsOfService;


-- Step 2: If the customer has booked before and the last booking was confirmed,
-- always assign them back to the same agent
WITH last_success AS (
    SELECT ah.AgentID
    FROM bookings b
    INNER JOIN assignment_history ah ON b.AssignmentID = ah.AssignmentID
    WHERE b.CustomerName = 'John Doe'
      AND b.BookingStatus = 'Confirmed'
    ORDER BY b.BookingDate DESC
    LIMIT 1
),

-- Step 3: Calculate contextual match factors for current request
comm AS (
    SELECT ah.AgentID,
           AVG(CASE WHEN b.BookingStatus = 'Confirmed' THEN 1 ELSE 0 END) AS CommConversionRate
    FROM assignment_history ah
    LEFT JOIN bookings b ON b.AssignmentID = ah.AssignmentID
    WHERE ah.CommunicationMethod = 'Text'
    GROUP BY ah.AgentID
),
lead_src AS (
    SELECT ah.AgentID,
           AVG(CASE WHEN b.BookingStatus = 'Confirmed' THEN 1 ELSE 0 END) AS LeadConversionRate
    FROM assignment_history ah
    LEFT JOIN bookings b ON b.AssignmentID = ah.AssignmentID
    WHERE ah.LeadSource = 'Organic'
    GROUP BY ah.AgentID
),
dest_rev AS (
    SELECT ah.AgentID,
           AVG(CASE WHEN b.BookingStatus = 'Confirmed' THEN b.TotalRevenue ELSE NULL END) AS DestinationAvgRevenue
    FROM assignment_history ah
    LEFT JOIN bookings b ON b.AssignmentID = ah.AssignmentID
    WHERE b.Destination = 'Mars'
    GROUP BY ah.AgentID
),
launch_conv AS (
    SELECT ah.AgentID,
           AVG(CASE WHEN b.BookingStatus = 'Confirmed' THEN 1 ELSE 0 END) AS LaunchConversionRate
    FROM assignment_history ah
    LEFT JOIN bookings b ON b.AssignmentID = ah.AssignmentID
    WHERE b.LaunchLocation = 'Dallas-Fort Worth Launch Complex'
    GROUP BY ah.AgentID
)

-- Step 4: Final score calculation
SELECT
    s.AgentID,
    s.FirstName,
    s.LastName,

    -- Score: If returning customer, score = 999 to guarantee top rank
    CASE
        WHEN s.AgentID = (SELECT AgentID FROM last_success) THEN 999.0
        ELSE (
            0.30 * (s.AverageCustomerServiceRating / 5.0) +
            0.25 * s.ConversionRate +
            0.25 * (s.AvgRevenuePerBooking / 200000.0) +
            0.10 * (s.YearsOfService / 20.0) +
            0.05 * COALESCE(c.CommConversionRate, s.ConversionRate) +
            0.05 * COALESCE(ls.LeadConversionRate, s.ConversionRate) +
            0.05 * (COALESCE(d.DestinationAvgRevenue, s.AvgRevenuePerBooking) / 200000.0) +
            0.05 * COALESCE(l.LaunchConversionRate, s.ConversionRate)
        )
    END AS Score

FROM agent_summary s
LEFT JOIN comm c ON s.AgentID = c.AgentID
LEFT JOIN lead_src ls ON s.AgentID = ls.AgentID
LEFT JOIN dest_rev d ON s.AgentID = d.AgentID
LEFT JOIN launch_conv l ON s.AgentID = l.AgentID
ORDER BY Score DESC;