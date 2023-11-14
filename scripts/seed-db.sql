-- Insert into Distilleries
INSERT INTO [dbo].[Distilleries] ([Name])
VALUES ('Highland Park'), ('Glenfiddich'), ('Macallan');

-- Insert into Customers
INSERT INTO [dbo].[Customers] ([FirstName], [LastName], [DateOfBirth], [Address])
VALUES ('John', 'Doe', '1980-05-15', '123 Whisky Lane'),
       ('Jane', 'Smith', '1987-08-22', '456 Bourbon Blvd'),
       ('Jim', 'Beam', '1975-12-01', '789 Rye Road');

-- Insert into Bottles
INSERT INTO [dbo].[Bottles] ([Name], [DistilleryId], [Age], [AlcoholByVolume], [WhiskyBaseId])
VALUES ('Viking Honour', 1, 12, 40.0, NULL),
       ('Reserve Cask', 2, 18, 43.0, NULL),
       ('Sherry Oak', 3, 25, 45.0, NULL);

-- Insert into Orders
INSERT INTO [dbo].[Orders] ([CustomerId], [Date], [Total], [BottleId])
VALUES (1, '2023-10-01', 150.00, 1),
       (2, '2023-10-05', 250.00, 2),
       (3, '2023-10-10', 450.00, 3);

-- Insert into Tastings
INSERT INTO [dbo].[Tastings] ([BottleId], [CustomerId], [Date], [Rating], [Notes])
VALUES (1, 1, '2023-10-02', 8, 'Smooth and balanced'),
       (2, 2, '2023-10-06', 9, 'Rich flavor'),
       (3, 3, '2023-10-11', 7, 'Exceptionally smooth');
